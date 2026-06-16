#!/usr/bin/env bash
# File: ./build-utils/create-script-tarball.sh

set -e
RELEASE=p701
R_TAR_GZ=r_${RELEASE}.tar.gz
CURRENT_DIR="$(pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Always create R_TAR_GZ in the project root directory for either call
cd "$PROJECT_DIR"

rm -f $R_TAR_GZ sonic_build_r_*.sh
cp build-utils/sbuild_r_${RELEASE}*.sh .
cp build-utils/README_series_r_${RELEASE}.txt .
tar czf $R_TAR_GZ \
    --exclude='files/master/TBD' \
    --exclude='files/master/tl' \
    --exclude='files/202511/tl' \
    files/202511 \
    files/master \
    *.sh \
    README_series_r_${RELEASE}.txt

