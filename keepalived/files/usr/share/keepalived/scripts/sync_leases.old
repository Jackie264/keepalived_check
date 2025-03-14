#!/bin/sh

if ip addr show | grep -q "192.88.9.1"; then
        logger "This device is MASTER, skipping lease sync"
        exit 0
fi

FLAG_FILE="/tmp/sync_leases_first_run"

# Delay only on the first run
if [ ! -f "$FLAG_FILE" ]; then
        sleep 5
        touch "$FLAG_FILE"
fi

# Path of the DHCP lease file on the master router
SOURCE_IP="192.88.9.5"
SOURCE_FILE="/tmp/dhcp.leases"

# Path of the DHCP lease file on the backup router (local)
TARGET_FILE="/tmp/dhcp.leases"

# Fetch the DHCP lease file from the master router
TMP_FILE="/tmp/dhcp.leases.tmp"
rsync -az "$SOURCE_IP:$SOURCE_FILE" "$TMP_FILE" >/dev/null 2>&1

if [ $? -ne 0 ]; then
        logger "Failed to fetch DHCP leases from master ($SOURCE_IP)"
        exit 1
fi

# Compare file contents
if cmp -s "$TMP_FILE" "$TARGET_FILE"; then
        logger "DHCP leases are identical, skipping sync"
        rm -f "$TMP_FILE"
        exit 0
else
        logger "DHCP leases changed, updating local file"
        mv "$TMP_FILE" "$TARGET_FILE"
fi
