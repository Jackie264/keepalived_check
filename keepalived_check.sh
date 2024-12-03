#!/bin/sh
# keepalived_check.sh

echo "Running keepalived_check.sh at $(date)"
logger "Running keepalived_check.sh at $(date)"

# Restart odhcpd if necessary
restart_odhcpd_if_needed() {
    if [ "$1" = true ]; then
        /etc/init.d/odhcpd restart
        echo "odhcpd restarted"
        logger "odhcpd restarted"
    fi
}

# Check if Keepalived is installed and get the current state
check_keepalived_state() {
    if ! [ -x "$(command -v keepalived)" ]; then
        echo "Keepalived is not installed, skipping DHCP adjustment"
        logger "Keepalived is not installed, skipping DHCP adjustment"
        return 0
    fi

    # Get the current state of Keepalived
    state=$(grep -m 1 'state' /tmp/keepalived.conf | awk '{print $2}' | tr -d '[:space:]' | tr -d '\n' | tr -d '\r')
    
    # If no state is found, log an error and exit
    if [ -z "$state" ]; then
        echo "Error: Unable to determine Keepalived state from /tmp/keepalived.conf"
        logger "Error: Unable to determine Keepalived state from /tmp/keepalived.conf"
        return 1
    fi

    # Output the current state
    echo "Detected Keepalived state: '$state'"
    logger "Detected Keepalived state: '$state'"

    restart_odhcpd=false

    if [ "$state" = "MASTER" ]; then
        echo "Keepalived state is MASTER, enabling DHCP, RA, and NDP"
        logger "Keepalived state is MASTER, enabling DHCP, RA, and NDP"

        # Enable DHCPv4
        uci get dhcp.lan.ignore &> /dev/null
        if [ $? -eq 0 ] && [ "$(uci get dhcp.lan.ignore)" = "1" ]; then
            uci set dhcp.lan.ignore='0'  # Set to 0 to enable DHCPv4
            uci commit dhcp
            /etc/init.d/dnsmasq reload
            echo "DHCPv4 enabled"
            logger "DHCPv4 enabled"
        else
            echo "DHCPv4 is already enabled (ignore not set to 1), skipping DHCP adjustment"
            logger "DHCPv4 is already enabled (ignore not set to 1), skipping DHCP adjustment"
        fi

        # Enable DHCPv6
        uci get dhcp.lan.dhcpv6 &> /dev/null
        if [ $? -eq 0 ] && [ "$(uci get dhcp.lan.dhcpv6)" = "disabled" ]; then
            uci set dhcp.lan.dhcpv6='server'
            uci commit dhcp
            restart_odhcpd=true
            echo "DHCPv6 enabled"
            logger "DHCPv6 enabled"
        else
            echo "DHCPv6 is already enabled, skipping DHCP adjustment"
            logger "DHCPv6 is already enabled, skipping DHCP adjustment"
        fi

        # Enable RA
        uci get dhcp.lan.ra &> /dev/null
        if [ $? -eq 0 ] && [ "$(uci get dhcp.lan.ra)" = "disabled" ]; then
            uci set dhcp.lan.ra='server'
            uci commit dhcp
            restart_odhcpd=true
            echo "RA enabled"
            logger "RA enabled"
        else
            echo "RA is already enabled, skipping DHCP adjustment"
            logger "RA is already enabled, skipping DHCP adjustment"
        fi

        # Enable NDP (set to relay)
        uci get dhcp.lan.ndp &> /dev/null
        if [ $? -eq 0 ] && [ "$(uci get dhcp.lan.ndp)" != "relay" ]; then
            uci set dhcp.lan.ndp='relay'
            uci commit dhcp
            restart_odhcpd=true
            echo "NDP set to relay"
            logger "NDP set to relay"
        else
            echo "NDP is already set to relay, skipping DHCP adjustment"
            logger "NDP is already set to relay, skipping DHCP adjustment"
        fi

    elif [ "$state" = "BACKUP" ]; then
        echo "Keepalived state is BACKUP, disabling DHCP, RA, and NDP"
        logger "Keepalived state is BACKUP, disabling DHCP, RA, and NDP"

        # Disable DHCPv4
        uci get dhcp.lan.ignore &> /dev/null
        if [ $? -ne 0 ] || [ "$(uci get dhcp.lan.ignore)" != "1" ]; then
            uci set dhcp.lan.ignore='1'
            uci commit dhcp
            /etc/init.d/dnsmasq reload
            echo "DHCPv4 disabled"
            logger "DHCPv4 disabled"
        else
            echo "DHCPv4 is already disabled (ignore is set to 1), skipping DHCP adjustment"
            logger "DHCPv4 is already disabled (ignore is set to 1), skipping DHCP adjustment"
        fi

        # Disable DHCPv6
        uci get dhcp.lan.dhcpv6 &> /dev/null
        if [ $? -eq 0 ] && [ "$(uci get dhcp.lan.dhcpv6)" != "disabled" ]; then
            uci set dhcp.lan.dhcpv6='disabled'
            uci commit dhcp
            restart_odhcpd=true
            echo "DHCPv6 disabled"
            logger "DHCPv6 disabled"
        else
            echo "DHCPv6 is already disabled, skipping DHCP adjustment"
            logger "DHCPv6 is already disabled, skipping DHCP adjustment"
        fi

        # Disable RA
        uci get dhcp.lan.ra &> /dev/null
        if [ $? -eq 0 ] && [ "$(uci get dhcp.lan.ra)" != "disabled" ]; then
            uci set dhcp.lan.ra='disabled'
            uci commit dhcp
            restart_odhcpd=true
            echo "RA disabled"
            logger "RA disabled"
        else
            echo "RA is already disabled, skipping DHCP adjustment"
            logger "RA is already disabled, skipping DHCP adjustment"
        fi

        # Disable NDP
        uci get dhcp.lan.ndp &> /dev/null
        if [ $? -eq 0 ] && [ "$(uci get dhcp.lan.ndp)" != "disabled" ]; then
            uci set dhcp.lan.ndp='disabled'
            uci commit dhcp
            restart_odhcpd=true
            echo "NDP disabled"
            logger "NDP disabled"
        else
            echo "NDP is already disabled, skipping DHCP adjustment"
            logger "NDP is already disabled, skipping DHCP adjustment"
        fi
    else
        echo "Unknown Keepalived state: $state, skipping DHCP adjustment"
        logger "Unknown Keepalived state: $state, skipping DHCP adjustment"
    fi

    # Call function to restart odhcpd if needed
    restart_odhcpd_if_needed "$restart_odhcpd"
}

# Execute the state check function
check_keepalived_state
