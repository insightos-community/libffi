#!/bin/sh
set -eu
cd /work
mkdir -p logs prefix dist
exec > logs/build.log 2>&1
apk add --no-cache build-base git binutils autoconf automake libtool texinfo dejagnu linux-headers
apk info -v > logs/apk-packages.txt
git config --global --add safe.directory '*'
cp -a /src source
cd source
sh autogen.sh > /work/logs/autogen.log 2>&1
CFLAGS='-O2 -fPIC' CXXFLAGS='-O2 -fPIC' ./configure --prefix=/work/prefix --libdir=/work/prefix/lib --disable-docs --disable-static > /work/logs/configure.log 2>&1
make -j2 > /work/logs/compile.log 2>&1
make check > /work/logs/tests.log 2>&1
make install > /work/logs/install.log 2>&1
cd /work
python /src/ci/musl/package.py
