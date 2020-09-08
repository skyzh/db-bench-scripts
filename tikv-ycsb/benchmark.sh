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

for WORKLOAD in workloada workloadb workloadc workloadd workloade workloadf
do
  echo Running $WORKLOAD
  /root/.tiup/bin/tiup playground &
  wait_tikv
  echo "TiKV up"
  sleep 10
  # restart tiup to clear all data (run by hand)
  (cd $GOPATH/src/github.com/pingcap/go-ycsb && ./bin/go-ycsb load tikv -P workloads/$WORKLOAD | tee logs/$WORKLOAD)
  sleep 5
  (cd $GOPATH/src/github.com/pingcap/go-ycsb && ./bin/go-ycsb run tikv -P workloads/$WORKLOAD | tee logs/$WORKLOAD)
  drop_cache_and_wait
  kill -9 %1
  fg
done
