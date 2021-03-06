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
	numKeys   = flag.Float64("keys", 10.0, "How many keys to write.")
	seq       = flag.Bool("seq", true, "Fill sequentially.")
	valueSize = flag.Int("value_size", 128, "Value size in bytes.")
	chunkSize = flag.Int("chunk_size", 128, "Item per txn")
	threads   = flag.Int("threads", 8, "goroutines")
	dir       = flag.String("dir", "", "Base dir for writes.")
)

var bdb *badger.DB

type entry struct {
	Key   []byte
	Value []byte
	Meta  byte
}

func fillEntry(e *entry, k int) {
	key := fmt.Sprintf("vsz=%05d-k=%010d", *valueSize, k) // 22 bytes.
	if cap(e.Key) < len(key) {
		e.Key = make([]byte, 2*len(key))
	}
	e.Key = e.Key[:len(key)]
	copy(e.Key, key)

	rand.Read(e.Value)
	e.Meta = 0
}

func writeBatch(entries []*entry, from int) int {
	for idx, e := range entries {
		if *seq {
			fillEntry(e, from+idx)
		} else {
			k := rand.Int() % int(*numKeys)
			fillEntry(e, k)
		}
	}

	txn := bdb.NewTransactionAt(uint64(time.Now().Unix()), true)

	for _, e := range entries {
		y.Check(txn.Set(e.Key, e.Value))
	}
	err := txn.CommitAt(uint64(time.Now().Unix()), nil)
	y.Check(err)
	return len(entries)
}

func humanize(n int64) string {
	return fmt.Sprintf("%.2f", float64(n))
}

func main() {
	flag.Parse()

	nw := *numKeys
	fmt.Printf("TOTAL KEYS TO WRITE: %s\n", humanize(int64(nw)))
	opt := badger.DefaultOptions(*dir).WithCompression(options.None).WithBlockCacheSize(0).WithIndexCacheSize(0)

	var err error

	bdb, err = badger.OpenManaged(opt)
	if err != nil {
		log.Fatalf("while opening badger: %v", err)
	}

	rc := ratecounter.NewRateCounter(time.Second)
	var counter int64
	ctx, cancel := context.WithCancel(context.Background())
	begin := time.Now().UnixNano()
	go func() {
		var count int64
		t := time.NewTicker(time.Second)
		defer t.Stop()
		for {
			select {
			case <-t.C:
				fmt.Printf("%d, rate: %s, total: %s\n",
					(time.Now().UnixNano()-begin)/int64(time.Second),
					humanize(rc.Rate()),
					humanize(atomic.LoadInt64(&counter)))
				count++
			case <-ctx.Done():
				return
			}
		}
	}()

	N := *threads
	var wg sync.WaitGroup
	threshold := make(chan struct{}, N)
	for i := 0; i < int(nw/float64(*chunkSize)); i++ {
		wg.Add(1)
		threshold <- struct{}{}
		go func(proc int) {
			entries := make([]*entry, *chunkSize)
			for i := 0; i < len(entries); i++ {
				e := new(entry)
				e.Key = make([]byte, 22)
				e.Value = make([]byte, *valueSize)
				entries[i] = e
			}

			wrote := float64(writeBatch(entries, proc*(*chunkSize)))

			wi := int64(wrote)
			atomic.AddInt64(&counter, wi)
			rc.Incr(wi)

			wg.Done()
			<-threshold
		}(i)
	}
	// 	wg.Add(1) // Block
	wg.Wait()
	cancel()

	bdb.Close()

	fmt.Printf("\nWROTE %d KEYS\n", atomic.LoadInt64(&counter))
}
