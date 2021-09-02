# Choose your desired base image

# oofem build container
# builds oofem with pybind11 bindings, binaries stored in /tmp/oofem/build (oofem liboofem.so oofempy.so)
#
FROM ubuntu:focal

USER root


ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update --yes && \
    apt-get install --yes --no-install-recommends build-essential cmake g++ python3 python3-pip python3-dev python3-pytest git && \
    apt-get clean && rm -fr /var/lib/apt/lists/*

# Install facets which does not have a pip or conda package at the moment
WORKDIR /tmp
RUN git clone https://github.com/oofem/oofem.git && \
    cd oofem; git submodule update --init  && \
    mkdir build &&\
    cd build; cmake -DCMAKE_BUILD_TYPE="Release" -DUSE_PYBIND_BINDINGS="ON" .. && \
    make -j 8

