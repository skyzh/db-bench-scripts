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
  for WORKLOAD in workloada workloadb workloadc workloadd workloade workloadf
  do
    for DB in default titan
    do
      echo Running $WORKLOAD
      rm -rf /home/tikv-data/*
      tiup playground --kv.config config-${DB}.toml &
      wait_tikv
      echo "TiKV up"
      sleep 10
      (cd $GOPATH/src/github.com/pingcap/go-ycsb && ./bin/go-ycsb load tikv -P workloads/$WORKLOAD -P $DIR/ycsb_${YCSB}.conf | tee $DIR/logs/${DB}_${WORKLOAD}_${YCSB}.load.log)
      sleep 5
      (cd $GOPATH/src/github.com/pingcap/go-ycsb && ./bin/go-ycsb run tikv -P workloads/$WORKLOAD -P $DIR/ycsb_${YCSB}.conf  | tee $DIR/logs/${DB}_${WORKLOAD}_${YCSB}.run.log)
      drop_cache_and_wait
      pkill tiup
      fg
      sleep 30
    done
  done
done

