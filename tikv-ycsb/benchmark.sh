#!/bin/bash

set -me

SLEEP_TIME=5

function drop_cache_and_wait {
  # sync; echo 3 > /proc/sys/vm/drop_caches 
  sleep $SLEEP_TIME 
}

function wait_tikv {
  until pgrep tikv; do 
    echo "Waiting TiKV..."
    sleep 1
  done
}

for YCSB in 1kb 16KB
do
  for WORKLOAD in workloada workloadb workloadc workloadd workloade workloadf
  do
    for DB in default titan
    do
      echo Running $WORKLOAD
      tiup playground --kv.config config-$DB.toml &
      wait_tikv
      echo "TiKV up"
      sleep 10
      (cd $GOPATH/src/github.com/pingcap/go-ycsb && ./bin/go-ycsb load tikv -P workloads/$WORKLOAD -p ycsb_$YCSB.conf | tee logs/$DB_$WORKLOAD_$YCSB)
      sleep 5
      (cd $GOPATH/src/github.com/pingcap/go-ycsb && ./bin/go-ycsb run tikv -P workloads/$WORKLOAD -p ycsb_$YCSB.conf | tee logs/$DB_$WORKLOAD_$YCSB)
      drop_cache_and_wait
      kill -9 %1
      fg
    done
  done
done
