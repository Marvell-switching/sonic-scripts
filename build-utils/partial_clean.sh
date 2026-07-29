#!/bin/bash

find target -name "*docker*" | grep -v trixie | grep -v versions | grep syncd | xargs rm -rf
find target -name "*syncd*"  | xargs rm -rf
find target -name "*swss*"   | xargs rm -rf
find target/debs/ -name "*platf*" | xargs rm -rf
rm -f target/sonic-marvell-prestera-arm64.bin*

