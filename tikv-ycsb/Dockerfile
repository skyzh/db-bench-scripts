FROM centos:latest
WORKDIR /app
RUN yum install curl wget git -y
RUN yum groupinstall "Development Tools" -y
RUN wget https://golang.org/dl/go1.15.linux-amd64.tar.gz
RUN tar -C /usr/local -xzf go1.15.linux-amd64.tar.gz
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/app"
RUN git clone https://github.com/pingcap/go-ycsb.git ${GOPATH}/src/github.com/pingcap/go-ycsb
RUN cd $GOPATH/src/github.com/pingcap/go-ycsb && make
RUN curl --proto '=https' --tlsv1.2 -sSf https://tiup-mirrors.pingcap.com/install.sh | sh

COPY ./ ./
RUN /app/install.sh

CMD /app/benchmark.sh

