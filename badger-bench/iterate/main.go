package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"sync/atomic"
	"time"

	"github.com/dgraph-io/badger/v2"
	"github.com/dgraph-io/badger/v2/options"
	"github.com/dgraph-io/badger/y"
	"github.com/paulbellamy/ratecounter"
)

const mil float64 = 1000000

var (
	times     = flag.Int("times", 50, "How many times to iterate.")
	valueSize = flag.Int("value_size", 128, "Value size in bytes.")
	threads   = flag.Int("threads", 8, "goroutines")
	dir       = flag.String("dir", "", "Base dir for writes.")
)

var bdb *badger.DB

type entry struct {
	Key   []byte
	Value []byte
	Meta  byte
}

func humanize(n int64) string {
	return fmt.Sprintf("%.2f", float64(n))
}

func main() {
	flag.Parse()

	opt := badger.DefaultOptions(*dir).WithCompression(options.None).WithBlockCacheSize(0).WithIndexCacheSize(0).WithSyncWrites(true)

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

	for i := 0; i < *times; i++ {
		txn := bdb.NewTransactionAt(uint64(time.Now().Unix()), false)
		opts := badger.DefaultIteratorOptions
		opts.PrefetchSize = 0
		opts.PrefetchValues = false
		it := txn.NewIterator(opts)
		it.Rewind()
		for ; it.Valid(); it.Next() {
			item := it.Item()
			val, err := item.ValueCopy(nil)
			y.Check(err)
			y.AssertTruef(len(val) == *valueSize,
				"Assertion failed. value size is %d, expected %d", len(val), *valueSize)
			atomic.AddInt64(&counter, 1)
			rc.Incr(1)
		}
		it.Close()
		txn.Discard()
	}
	cancel()

	bdb.Close()

	fmt.Printf("\nWROTE %d KEYS\n", atomic.LoadInt64(&counter))
}
