FROM ubuntu:latest
WORKDIR /app
RUN apt-get update -qq -y && apt-get install libgflags-dev libsnappy-dev zlib1g-dev libbz2-dev liblz4-dev libzstd-dev git build-essential -qq -y
RUN git clone https://github.com/facebook/rocksdb
RUN cd rocksdb && git checkout v6.4.6 && make db_bench -j4 DEBUG_LEVEL=0
