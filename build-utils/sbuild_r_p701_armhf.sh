#!/bin/bash

# Force TARGET-armhf build on arm64:QEMU
export SONIC_TARGET_ARCH=armhf
./sbuild_r_p701.sh $@
