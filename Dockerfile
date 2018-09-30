FROM alpine:edge as builder

RUN apk update && \
    apk add \
        gcc \
        g++ \
        automake \
        autoconf \
        pkgconfig \
        python2-dev \
        cmake \
        make \
        libc-dev \
        binutils \
        zlib-dev \
        libstdc++

RUN mkdir -p /deps
ARG MAKE_JOBS=-j1

# xml2
WORKDIR /deps
RUN wget ftp://ftp.xmlsoft.org/libxml2/libxml2-2.9.7.tar.gz
RUN tar xf libxml2-2.9.7.tar.gz
WORKDIR /deps/libxml2-2.9.7
RUN autoreconf
RUN ./configure --without-python --disable-shared --prefix=/deps/local
RUN make $MAKE_JOBS install

# llvm
WORKDIR /deps
RUN wget http://releases.llvm.org/7.0.0/llvm-7.0.0.src.tar.xz
RUN tar xf llvm-7.0.0.src.tar.xz
WORKDIR /deps/llvm-7.0.0.src/
COPY llvm-fix-libxml2-dep.patch ./
RUN patch -p0 -i llvm-fix-libxml2-dep.patch
RUN mkdir -p /deps/llvm-7.0.0.src/build
WORKDIR /deps/llvm-7.0.0.src/build
RUN cmake .. -DCMAKE_INSTALL_PREFIX=/deps/local -DCMAKE_PREFIX_PATH=/deps/local -DCMAKE_BUILD_TYPE=Release -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD="WebAssembly;AVR;RISCV"
RUN make $MAKE_JOBS install

# clang
WORKDIR /deps
RUN wget http://releases.llvm.org/7.0.0/cfe-7.0.0.src.tar.xz
RUN tar xf cfe-7.0.0.src.tar.xz
RUN mkdir -p /deps/cfe-7.0.0.src/build
WORKDIR /deps/cfe-7.0.0.src/build
RUN cmake .. -DCMAKE_INSTALL_PREFIX=/deps/local -DCMAKE_PREFIX_PATH=/deps/local -DCMAKE_BUILD_TYPE=Release
RUN make $MAKE_JOBS install

FROM alpine:edge
RUN apk update && \
    apk add \
        gcc \
        g++ \
        python2-dev \
        cmake \
        make \
        libc-dev \
        binutils \
        zlib-dev \
        libstdc++ \
        git \
        xz
COPY --from=builder /deps/local/lib /deps/local/lib
COPY --from=builder /deps/local/include /deps/local/include
COPY --from=builder /deps/local/bin/llvm-config /deps/local/bin/llvm-config
COPY build /deps/build

ENTRYPOINT ["/deps/build"]
