FROM ubuntu:latest
WORKDIR /app
RUN apt-get update -qq -y
RUN DEBIAN_FRONTEND=noninteractive apt-get install libgflags-dev libsnappy-dev zlib1g-dev libbz2-dev liblz4-dev libzstd-dev git build-essential cmake -qq -y
RUN git clone https://github.com/tikv/titan
RUN cd titan && mkdir build && cd build && cmake .. -DCMAKE_BUILD_TYPE=Release -DWITH_SNAPPY=ON
COPY ./patch /app
RUN cd titan/build/rocksdb && git apply ../../../patch
RUN cd titan/build && make -j4
