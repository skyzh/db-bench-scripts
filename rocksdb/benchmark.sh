#!/bin/bash

set -e

export LOG_DIR=$HOME/skyzh/logs
export NUM_THREADS=64
export CACHE_SIZE=5368709120
DURATION=600   # run query for 10 minutes
SLEEP_TIME=60  # sleep for 60 secs for each case, so we can observe disk I/O in prometheus
# NUM_KEYS_ITER=( 419430400 26214400 1638400 102400 )
# VALUE_SIZES=( 256 4096 65536 1048576 )

NUM_KEYS_ITER=( 100 200 300 400 )
VALUE_SIZES=( 23331 23332 23333 2333 )

function drop_cache_and_wait {
  sync; echo 3 > /proc/sys/vm/drop_caches
  sleep $SLEEP_TIME
}

mkdir $LOG_DIR || true

ROCKSDB_PATH=$HOME/skyzh/rocksdb
TITAN_PATH=$HOME/skyzh/titan/build

for idx in "${!NUM_KEYS_ITER[@]}"; do
  export BENCH_TARGET=rocksdb
  cd $ROCKSDB_PATH
  export DB_DIR=$HOME/skyzh/${BENCH_TARGET}_bench_tmp
  export WAL_DIR=$HOME/skyzh/${BENCH_TARGET}_bench_tmp_wal
  rm -rf $DB_DIR
  rm -rf $WAL_DIR
  export NUM_KEYS=${NUM_KEYS_ITER[$idx]}
  export VALUE_SIZE=${VALUE_SIZES[$idx]}
  export OUTPUT_DIR=$LOG_DIR/${BENCH_TARGET}_${VALUE_SIZE}
  mkdir $OUTPUT_DIR || true
  echo "NUM_KEYS=$NUM_KEYS, VALUE_SIZE=$VALUE_SIZE, writing to ${OUTPUT_DIR}"
  tools/benchmark.sh bulkload
  drop_cache_and_wait
  DURATION=$DURATION tools/benchmark.sh overwrite
  drop_cache_and_wait
  DURATION=$DURATION tools/benchmark.sh readrandom
  drop_cache_and_wait
  DURATION=$DURATION tools/benchmark.sh fwdrange
  drop_cache_and_wait
  du -sh $DB_DIR > ${OUTPUT_DIR}/on_disk_size.log

  export BENCH_TARGET=titan
  cd $TITAN_PATH
  export DB_DIR=$HOME/skyzh/${BENCH_TARGET}_bench_tmp
  export WAL_DIR=$HOME/skyzh/${BENCH_TARGET}_bench_tmp_wal
  rm -rf $DB_DIR
  rm -rf $WAL_DIR
  export NUM_KEYS=${NUM_KEYS_ITER[$idx]}
  export VALUE_SIZE=${VALUE_SIZES[$idx]}
  export OUTPUT_DIR=$LOG_DIR/${BENCH_TARGET}_${VALUE_SIZE}
  mkdir $OUTPUT_DIR || true
  echo "NUM_KEYS=$NUM_KEYS, VALUE_SIZE=$VALUE_SIZE, writing to ${OUTPUT_DIR}"
  tools/benchmark.sh bulkload
  drop_cache_and_wait
  DURATION=$DURATION tools/benchmark.sh overwrite
  drop_cache_and_wait
  DURATION=$DURATION tools/benchmark.sh readrandom
  drop_cache_and_wait
  DURATION=$DURATION tools/benchmark.sh fwdrange
  drop_cache_and_wait
  du -sh $DB_DIR > ${OUTPUT_DIR}/on_disk_size.log
done
