#!/bin/bash

set -m

/root/.tiup/bin/tiup playground --db 0 --kv 0 --tiflash 0 --pd 0 --monitor false
