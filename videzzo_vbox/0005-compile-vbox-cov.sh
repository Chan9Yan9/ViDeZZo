#!/bin/bash

pushd vbox
mkdir -p out-cov
./configure --disable-hardening --disable-docs \
    --disable-java --disable-qt -d --out-base-dir=out-cov
pushd out-cov && source ./env.sh && popd
COVERAGE="-fprofile-instr-generate -fcoverage-mapping"
kmk VBOX_FUZZ=1 KBUILD_TYPE=debug VBOX_GCC_TOOL=CLANG \
    PATH_OUT_BASE=$PWD/out-cov \
    TOOL_CLANG_CFLAGS="-fsanitize=fuzzer-no-link -DCLANG_COV_DUMP -DVIDEZZO_LESS_CRASHES ${COVERAGE} -fPIE" \
    TOOL_CLANG_CXXFLAGS="-fsanitize=fuzzer-no-link -DCLANG_COV_DUMP -DVIDEZZO_LESS_CRASHES ${COVERAGE} -fPIE" \
    TOOL_CLANG_LDFLAGS="-fsanitize=fuzzer-no-link ${COVERAGE}" \
    VBOX_FUZZ_LDFLAGS="-fsanitize=fuzzer ${COVERAGE}"

# 1. compile kernel drivers
pushd out-cov/linux.amd64/debug/bin/
pushd src
sudo make && sudo make install
# 2. install kernel drivers
sudo rmmod vboxnetadp vboxnetflt vboxdrv
sudo insmod vboxdrv.ko
sudo insmod vboxnetflt.ko
sudo insmod vboxnetadp.ko
popd
popd
popd