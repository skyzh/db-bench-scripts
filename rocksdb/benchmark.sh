#!/bin/bash

set -xe

cd rocksdb

echo "Running benchmark for $BENCH_TARGET"

# DURATION=1
# SLEEP_TIME=1
# NUM_KEYS_ITER=( 1000 100 100 100 )

export DB_DIR=/data2/skyzh/${BENCH_TARGET}_bench_tmp
export WAL_DIR=/data2/skyzh/${BENCH_TARGET}_bench_tmp_wal
export LOG_DIR=/data2/skyzh/logs
export NUM_THREADS=64
export CACHE_SIZE=5368709120
DURATION=600   # run query for 10 minutes
SLEEP_TIME=60  # sleep for 60 secs for each case, so we can observe disk I/O in prometheus
NUM_KEYS_ITER=( 419430400 26214400 1638400 102400 )
VALUE_SIZES=( 64 1024 16384 262144 )

function drop_cache_and_wait {
  sync; echo 3 > /proc/sys/vm/drop_caches
  sleep $SLEEP_TIME
}

mkdir $LOG_DIR || true

for idx in "${!NUM_KEYS_ITER[@]}"; do
  rm -rf $DB_DIR
  rm -rf $WAL_DIR
  export NUM_KEYS=${NUM_KEYS_ITER[$idx]}
  export VALUE_SIZE=${VALUE_SIZES[$idx]}
  export OUTPUT_DIR=$LOG_DIR/${BENCH_TARGET}_${VALUE_SIZE}
  mkdir $OUTPUT_DIR || true
  echo "NUM_KEYS=$NUM_KEYS, VALUE_SIZE=$VALUE_SIZE, writing to ${OUTPUT_DIR}"
  tools/benchmark.sh bulkload | tee ${OUTPUT_DIR}/stdout_bulkload.log
  drop_cache_and_wait
  DURATION=$DURATION tools/benchmark.sh overwrite | tee ${OUTPUT_DIR}/stdout_overwrite.log
  drop_cache_and_wait
  DURATION=$DURATION tools/benchmark.sh readrandom | tee ${OUTPUT_DIR}/stdout_readrandom.log
  drop_cache_and_wait
  DURATION=$DURATION tools/benchmark.sh fwdrange | tee ${OUTPUT_DIR}/stdout_fwdrange.log
  drop_cache_and_wait
  du -sh $DB_DIR > ${OUTPUT_DIR}/on_disk_size.log
done
