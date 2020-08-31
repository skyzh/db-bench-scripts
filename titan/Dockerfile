FROM ubuntu:latest
WORKDIR /app
RUN apt-get update -qq -y
RUN DEBIAN_FRONTEND=noninteractive apt-get install libgflags-dev libsnappy-dev zlib1g-dev libbz2-dev liblz4-dev libzstd-dev git build-essential cmake -qq -y
RUN git clone https://github.com/tikv/titan
RUN cd titan && mkdir build && cd build && cmake .. -DCMAKE_BUILD_TYPE=Release -DWITH_SNAPPY=ON -DWITH_BZ2=ON -DWITH_LZ4=ON -DWITH_ZLIB=ON -DWITH_ZSTD=ON
COPY ./patch /app
RUN cd titan/build/rocksdb && git apply ../../../patch
RUN cd titan/build && make -j4
RUN cd titan/build && cp titandb_bench db_bench
