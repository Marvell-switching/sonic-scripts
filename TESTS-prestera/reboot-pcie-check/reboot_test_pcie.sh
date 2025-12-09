#!/bin/bash
# ---------------- PCIE test ---------------------------
# SONiC docker is disabled by removing => pure Debian test
# RESULTs saved in   /host/reboot_test/*

CONSOLE="/dev/console"
BASE="/host/reboot_test"
CNTR="$BASE/reboot_cntr"

# Read and increment counter
CNTR_VAL=$(cat "$CNTR")
CNTR_VAL=$((CNTR_VAL + 1))
echo "$CNTR_VAL" > "$CNTR"

# with NO docker --> no SONiC test. STOP on error
mv /usr/bin/docker /usr/bin/docker-ORIG 2>/dev/null || true

echo "PCIE reboot_test no.$CNTR_VAL started ---------------------------" >$CONSOLE
sleep 20

VENDOR=$(cat /sys/bus/pci/devices/0000:01:00.0/vendor 2>/dev/null)
DEVICE=$(cat /sys/bus/pci/devices/0000:01:00.0/device 2>/dev/null)

# VENDOR: Marvell 0x11ab
# DEVICE:
#  AC5P-cn9131:
#  AC5X-cn9131: 0000:01:00.0 Ethernet controller: Marvell Technology Group Ltd. Device 9805
#  Nokia-AC5x:  0000:01:00.0 Ethernet controller: Marvell Technology Group Ltd. Device 9821
#  Nokia-AC3x:       01:00.0 Ethernet controller: Marvell Technology Group Ltd. Device c804
#                    02:00.0 Ethernet controller: Marvell Technology Group Ltd. Device c804

lspci|grep Marvell > $CONSOLE

if [ "$VENDOR" = "0x11ab" ]; then
    echo "PCIE reboot_test no.$CNTR_VAL passed" >$CONSOLE
else
    echo "PCIE reboot_test no.$CNTR_VAL failed" >$CONSOLE
    dmesg > "$BASE/dmreboot.$CNTR_VAL.flt"
echo "------- PCIE TEST FAILED. STOP, no reboot -----------------------" >$CONSOLE 
exit 1
fi

dmesg > /tmp/dmreboot.$CNTR_VAL
sync
rm -rf /tmp/dmreboot.$CNTR_VAL
ls -l "$BASE"/dmreboot.*.flt >"$CONSOLE" 2>/dev/null || true
echo "PCIE -----------------------------------------------------------" >$CONSOLE

# Reboot system
rm -rf /var/log/syslog*
reboot

exit 0

## Quick enter and stop ---------------------------
/host/reboot_test/reboot_test_uninstall.sh

ls -l /host/reboot_test/*

