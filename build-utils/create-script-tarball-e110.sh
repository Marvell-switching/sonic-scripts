#!/usr/bin/env bash
# File: ./build-utils/create-script-tarball-e110.sh

set -e
RELEASE=e110
R_TAR_GZ=r_${RELEASE}.tar.gz
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

rm -f "$R_TAR_GZ"
tar czf "$R_TAR_GZ" \
    --exclude='files/202605/tl' \
    --transform='s|^build-utils/||' \
    files/202605 \
    sonic_build_script.sh \
    marvell_sonic_patch_script.sh \
    README_eSAI.md \
    "build-utils/sbuild_r_${RELEASE}.sh"

echo "Created ${PROJECT_DIR}/${R_TAR_GZ}"
