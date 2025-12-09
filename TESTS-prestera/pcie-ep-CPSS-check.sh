#!/bin/sh
# mrvl-check-pcie-ep.sh
#  Check Marvell-End-Point presence, reboot if not found
#
# Run on Init context, service-safe, logs via /dev/kmsg

# Conditional: only for CN9131-DB-Comexpress
if ! grep -iq "CN9131-DB-Comexpress" /proc/device-tree/model 2>/dev/null; then
    # Not the target model -> exit clean
    exit 0
fi

# EVENT_FILE is persistent marker file preventing loop on persistent miss
EVENT_FILE="/var/lib/mrvl-pcie-ep-reboot.req"
STAT_PASS="/var/lib/mrvl-pcie-ep-reboot.pass"
STAT_FAIL="/var/lib/mrvl-pcie-ep-reboot.fail"

# Find PCIe endpoint (Marvell vendor, not root-port)
EP=""
for d in /sys/bus/pci/devices/*; do
    vend=$(cat "$d/vendor" 2>/dev/null)
    cls=$(cat "$d/class"  2>/dev/null)

    case "$vend:$cls" in
        0x11ab:0x0604??) ;;      # skip bridges/root-ports
        0x11ab:0x??????) EP="$d"; break ;; # endpoint 020000 found
    esac
done

# Handle PCIe endpoint presence
if [ ! -z "$EP" ]; then
    # PCIe OK -> remove any previous marker
    [ -f "$EVENT_FILE" ] && rm -f "$EVENT_FILE"
    CNTR_PASS=$(cat "$STAT_PASS" 2>/dev/null)
    CNTR_PASS=$((CNTR_PASS + 1))
    echo "$CNTR_PASS" > "$STAT_PASS"
    exit 0
fi

CNTR_FLT=$(cat "$STAT_FAIL" 2>/dev/null)
CNTR_FLT=$((CNTR_FLT + 1))
echo "$CNTR_FLT" > "$STAT_FAIL"

echo "ERROR: Marvell PCIe endpoint missing" >/dev/kmsg
echo "=================================================" >/dev/console
echo "ERROR: Marvell PCIe endpoint missing"              >/dev/console
echo "=================================================" >/dev/console
if [ ! -f "$EVENT_FILE" ]; then
    touch "$EVENT_FILE"
    sync
    reboot
fi
exit 0
