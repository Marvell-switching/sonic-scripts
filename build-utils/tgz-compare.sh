#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: $0 <tgz1> <tgz2>" >&2
    echo "      Utility to check tgz-files created in a different time"
    echo "                          have the same or different content"
    exit 2
fi

TGZ1="$1"
TGZ2="$2"

rm -rf /tmp/TGZcmp1 /tmp/TGZcmp2
mkdir /tmp/TGZcmp1 /tmp/TGZcmp2

tar xf "$TGZ1" -C /tmp/TGZcmp1
tar xf "$TGZ2" -C /tmp/TGZcmp2

# First comparison: silent
diff -r /tmp/TGZcmp1 /tmp/TGZcmp2 >/dev/null 2>&1
TGZ_IS_SAME=$?

if [ "$TGZ_IS_SAME" -eq 0 ]; then
    echo "<$TGZ1> and <$TGZ2> are same"
    rm -rf /tmp/TGZcmp1 /tmp/TGZcmp2
else
    echo "  <$TGZ1> and <$TGZ2> are DIFFERENT"
    echo "    To see the differences apply"
    echo "diff -r /tmp/TGZcmp1/ /tmp/TGZcmp2/"
    echo "-----------------------------------"
    #rm -rf /tmp/TGZcmp1 /tmp/TGZcmp2
fi

exit "$TGZ_IS_SAME"

