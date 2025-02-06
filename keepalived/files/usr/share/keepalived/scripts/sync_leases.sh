#!/bin/sh

sleep 60

LEASE_FILE="/tmp/dhcp.leases"

MASTER_IP="<master-router-ip>"

rsync -avz root@$MASTER_IP:"$LEASE_FILE" "$LEASE_FILE"
if [ $? -eq 0 ]; then
	logger "DHCP leases synced successfully from master router ($MASTER_IP)"
else
	logger "Failed to sync DHCP leases from master router ($MASTER_IP)"
fi
