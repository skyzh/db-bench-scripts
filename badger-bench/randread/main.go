package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"math/rand"
	"sync"
	"sync/atomic"
	"time"

	"github.com/dgraph-io/badger/v2"
	"github.com/dgraph-io/badger/v2/options"
	"github.com/dgraph-io/badger/v2/y"
	"github.com/paulbellamy/ratecounter"
)

const mil float64 = 1000000

var (
	numKeys   = flag.Float64("keys", 10.0, "How many keys to read.")
	times     = flag.Int("times", 16, "How many times to read")
	valueSize = flag.Int("value_size", 128, "Value size in bytes.")
	chunkSize = flag.Int("chunk_size", 128, "Item per txn")
	threads   = flag.Int("threads", 8, "goroutines")
	dir       = flag.String("dir", "", "Base dir for reads.")
)

var bdb *badger.DB

type entry struct {
	Key   []byte
	Value []byte
	Meta  byte
}

func fillEntry(e *entry) {
	k := rand.Int() % int(*numKeys)
	key := fmt.Sprintf("vsz=%05d-k=%010d", *valueSize, k) // 22 bytes.
	if cap(e.Key) < len(key) {
		e.Key = make([]byte, 2*len(key))
	}
	e.Key = e.Key[:len(key)]
	copy(e.Key, key)

	e.Meta = 0
}

func readBatch(entries []*entry) (int, int) {
	for _, e := range entries {
		fillEntry(e)
	}

	txn := bdb.NewTransactionAt(uint64(time.Now().Unix()), false)

	var found, missing int
	for _, e := range entries {
		item, err := txn.Get(e.Key)
		if err == badger.ErrKeyNotFound {
			missing++
			continue
		}
		y.Check(err)
		val, err := item.ValueCopy(nil)
		y.Check(err)
		y.AssertTruef(len(val) == *valueSize,
			"Assertion failed. value size is %d, expected %d", len(val), *valueSize)
		found++
	}
	txn.Discard()
	return found, missing
}

func humanize(n int64) string {
	return fmt.Sprintf("%.2f", float64(n))
}

func main() {
	flag.Parse()

	nw := *numKeys
	fmt.Printf("TOTAL KEYS TO READ: %s\n", humanize(int64(nw)))
	opt := badger.DefaultOptions(*dir).WithCompression(options.None).WithBlockCacheSize(0).WithIndexCacheSize(0).WithSyncWrites(true)

	var err error

	bdb, err = badger.OpenManaged(opt)
	if err != nil {
		log.Fatalf("while opening badger: %v", err)
	}

	rc := ratecounter.NewRateCounter(time.Second)
	var totalFound int64
	var totalMissing int64
	ctx, cancel := context.WithCancel(context.Background())
	begin := time.Now().UnixNano()
	go func() {
		var count int64
		t := time.NewTicker(time.Second)
		defer t.Stop()
		for {
			select {
			case <-t.C:
				fmt.Printf("%d, rate: %s, found: %s, missing: %s\n",
					(time.Now().UnixNano()-begin)/int64(time.Second),
					humanize(rc.Rate()),
					humanize(atomic.LoadInt64(&totalFound)),
					humanize(atomic.LoadInt64(&totalMissing)))
				count++
			case <-ctx.Done():
				return
			}
		}
	}()

	N := *threads
	threshold := make(chan struct{}, N)
	var wg sync.WaitGroup
	for i := 0; i < N*(*times); i++ {
		wg.Add(1)
		threshold <- struct{}{}
		go func(proc int) {
			var readTotal float64

			entries := make([]*entry, *chunkSize)
			for i := 0; i < len(entries); i++ {
				e := new(entry)
				e.Key = make([]byte, 22)
				e.Value = make([]byte, *valueSize)
				entries[i] = e
			}

			for readTotal < nw/float64(N) {
				found, missing := readBatch(entries)

				rd := int64(found) + int64(missing)
				atomic.AddInt64(&totalFound, int64(found))
				atomic.AddInt64(&totalMissing, int64(missing))
				rc.Incr(rd)

				readTotal += float64(rd)
			}
			wg.Done()
			<-threshold
		}(i)
	}
	// 	wg.Add(1) // Block
	wg.Wait()
	cancel()

	bdb.Close()

	fmt.Printf("\nFOUND %d KEYS\nMISSED %d KEYS", atomic.LoadInt64(&totalFound), atomic.LoadInt64(&totalMissing))
}
