#!/bin/bash

###############################################################################
# Apply <0001-sonic_installer-add-sync-before-migration.patch>
# to fix Time-Out problem on a slow or removable disk
# (on which 'sync' command could take from 1 to 15! minutes).
# 
# The script gets the current python version, goes into appropriated
#    /usr/local/lib/python3.${PYTHON_VERSION}/dist-packages directory
# and makes self-extraction for the patch.
###############################################################################

PYTHON_VERSION=$(python3 --version 2>&1 | grep -oP 'Python 3\.\K[0-9]+')
if [ -z "$PYTHON_VERSION" ]; then
    echo "FAILED: Could not detect Python3 version."
    exit 1
fi

PATCH_DIR="/usr/local/lib/python3.${PYTHON_VERSION}/dist-packages"

if [ ! -d "$PATCH_DIR" ]; then
    echo "FAILED: Directory $PATCH_DIR does not exist."
    exit 1
fi

cd "$PATCH_DIR" || { echo "FAILED: Cannot change directory to $PATCH_DIR"; exit 1; }

TMP_PATCH=$(mktemp)
cat << 'EOF' > "$TMP_PATCH"
From c113b0d1d550b8c51cd31b1af5c29840bb9e325f Mon Sep 17 00:00:00 2001
From: Yan Markman <ymarkman@marvell.com>
Date: Sun, 22 Jun 2025 18:09:40 +0300
Subject: [PATCH 1/1] sonic_installer: add sync before migration

Add extra 'sync' command to the sonic_installer to eliminate
timeout failure in the following command
 chroot /tmp/image-fs sonic-package-manager \
   migrate /tmp/packages.json --dockerd-socket /tmp/docker.sock
on a slow or removable disk (for example - on Intel-Falcon board).

This sync should be called before first chroot.

Signed-off-by: Yan Markman <ymarkman@marvell.com>
---
 sonic_installer/main.py | 6 ++++++
 1 file changed, 6 insertions(+)

diff --git a/sonic_installer/main.py b/sonic_installer/main.py
index 6a445504..4cc48725 100644
--- a/sonic_installer/main.py
+++ b/sonic_installer/main.py
@@ -358,6 +358,12 @@ def migrate_sonic_packages(bootloader, binary_image_version):
             run_command_or_raise(["mkdir", "-p", new_image_work_dir])
             mount_overlay_fs(new_image_mount, new_image_upper_dir, new_image_work_dir, new_image_mount)
             mount_bind(new_image_docker_dir, new_image_docker_mount)
+
+            # sync to eliminate timeout on the
+            # chroot /tmp/image-fs SONIC_PACKAGE_MANAGER migrate /tmp/packages.json --dockerd-socket DOCKERD_SOCK
+            click.echo('Command sync ...   could take several seconds on slow or removable disk')
+            run_command(["sync"])
+
             mount_procfs_chroot(new_image_mount)
             mount_sysfs_chroot(new_image_mount)
             # Assume if docker.sh script exists we are installing Application Extension compatible image.
-- 
2.25.1
EOF

echo "Checking if patch is already applied to $PATCH_DIR/sonic_installer/main.py..."

# Run normal dry-run patch to see if it's already applied
PATCH_OUTPUT=$(patch --dry-run -p1 < "$TMP_PATCH" 2>&1)

if echo "$PATCH_OUTPUT" | grep -q "Reversed (or previously applied) patch detected"; then
    rm -f "$TMP_PATCH"
    echo "Patch already installed on $PATCH_DIR/sonic_installer/main.py. Try to upgrade the SONiC."
    exit 0
fi

# Apply the patch for real
if patch -p1 < "$TMP_PATCH"; then
    rm -f "$TMP_PATCH"
    echo "patching $PATCH_DIR/sonic_installer/main.py is OK. Ready to upgrade the SONiC."
    exit 0
else
    rm -f "$TMP_PATCH"
    echo "patching $PATCH_DIR/sonic_installer/main.py FAILED."
    exit 1
fi
