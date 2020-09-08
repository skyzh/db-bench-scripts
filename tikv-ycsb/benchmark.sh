#!/bin/bash

set -me

trap 'kill $(jobs -p)' EXIT

SLEEP_TIME=5

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

function drop_cache_and_wait {
  # sync; echo 3 > /proc/sys/vm/drop_caches 
  sleep $SLEEP_TIME 
}

function wait_tikv {
  until pgrep tiflash; do 
    echo "Waiting..."
    sleep 1
  done
}

for YCSB in 1kb 16kb
do
  for DB in default titan
  do
    rm -rf /home/tikv-data/*
    tiup playground --kv.config config-${DB}.toml &
    wait_tikv
    echo "TiKV up"
    sleep 10
    export WORKLOAD=workloada
    (cd $GOPATH/src/github.com/pingcap/go-ycsb && ./bin/go-ycsb load tikv -P workloads/$WORKLOAD -P $DIR/ycsb_${YCSB}.conf | tee $DIR/logs/${DB}_${WORKLOAD}_${YCSB}.load.log)
    sleep 5
    export WORKLOAD=workloada
    (cd $GOPATH/src/github.com/pingcap/go-ycsb && ./bin/go-ycsb run tikv -P workloads/$WORKLOAD -P $DIR/ycsb_${YCSB}.conf  | tee $DIR/logs/${DB}_${WORKLOAD}_${YCSB}.run.log)
    export WORKLOAD=workloadb
    (cd $GOPATH/src/github.com/pingcap/go-ycsb && ./bin/go-ycsb run tikv -P workloads/$WORKLOAD -P $DIR/ycsb_${YCSB}.conf  | tee $DIR/logs/${DB}_${WORKLOAD}_${YCSB}.run.log)
    export WORKLOAD=workloadc
    (cd $GOPATH/src/github.com/pingcap/go-ycsb && ./bin/go-ycsb run tikv -P workloads/$WORKLOAD -P $DIR/ycsb_${YCSB}.conf  | tee $DIR/logs/${DB}_${WORKLOAD}_${YCSB}.run.log)
    export WORKLOAD=workloadf
    (cd $GOPATH/src/github.com/pingcap/go-ycsb && ./bin/go-ycsb run tikv -P workloads/$WORKLOAD -P $DIR/ycsb_${YCSB}.conf  | tee $DIR/logs/${DB}_${WORKLOAD}_${YCSB}.run.log)
    export WORKLOAD=workloadd
    (cd $GOPATH/src/github.com/pingcap/go-ycsb && ./bin/go-ycsb run tikv -P workloads/$WORKLOAD -P $DIR/ycsb_${YCSB}.conf  | tee $DIR/logs/${DB}_${WORKLOAD}_${YCSB}.run.log)
    pkill tiup
    fg
    drop_cache_and_wait
    sleep 30
    
    rm -rf /home/tikv-data/*
    tiup playground --kv.config config-${DB}.toml &
    wait_tikv
    echo "TiKV up"
    sleep 10
    export WORKLOAD=workloade
    (cd $GOPATH/src/github.com/pingcap/go-ycsb && ./bin/go-ycsb load tikv -P workloads/$WORKLOAD -P $DIR/ycsb_${YCSB}.conf | tee $DIR/logs/${DB}_${WORKLOAD}_${YCSB}.load.log)
    sleep 5
    export WORKLOAD=workloade
    (cd $GOPATH/src/github.com/pingcap/go-ycsb && ./bin/go-ycsb run tikv -P workloads/$WORKLOAD -P $DIR/ycsb_${YCSB}.conf  | tee $DIR/logs/${DB}_${WORKLOAD}_${YCSB}.run.log)
    pkill tiup
    fg
    drop_cache_and_wait
    sleep 30
  done
done
