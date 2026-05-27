#!/bin/bash
set -e

BASE="/host/reboot_test"
CNTR="$BASE/reboot_cntr"
SRV="/etc/systemd/system/reboot_test.service"

mkdir -p "$BASE"

# Create counter file if does not exist
echo 0 > "$CNTR"

# Create systemd service
cat > "$SRV" <<EOF
[Unit]
Description=Reboot Test Automation
After=multi-user.target

[Service]
Type=simple
ExecStart=$BASE/reboot_test_run.sh
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable
systemctl daemon-reload
systemctl enable reboot_test.service

echo "reboot_test installed. Will start automatically after next reboot."
