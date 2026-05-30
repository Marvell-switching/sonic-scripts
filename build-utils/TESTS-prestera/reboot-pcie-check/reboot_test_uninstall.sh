#!/bin/bash

SRV="/etc/systemd/system/reboot_test.service"

# Stop NOW (even if sleep 220 is running)
systemctl stop reboot_test.service 2>/dev/null || true
systemctl disable reboot_test.service 2>/dev/null || true

rm -f "$SRV"

systemctl daemon-reload

echo "reboot_test uninstalled and stopped."
