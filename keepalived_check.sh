#!/bin/sh
# keepalived_check.sh

echo "Running keepalived_check.sh at $(date)"
logger "Running keepalived_check.sh at $(date)"

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

    # Adjust DHCP configuration based on the current state
    if [ "$state" = "MASTER" ]; then
        echo "Keepalived state is MASTER, enabling DHCP and RA"
        logger "Keepalived state is MASTER, enabling DHCP and RA"

        # Enable DHCPv4
        uci get dhcp.lan.ignore &> /dev/null
        if [ $? -eq 0 ] && [ "$(uci get dhcp.lan.ignore)" = "1" ]; then
            uci set dhcp.lan.ignore='0'  # Set to 0 to enable DHCPv4
            uci commit dhcp
            /etc/init.d/dnsmasq reload
            echo "DHCPv4 enabled"
            logger "DHCPv4 enabled"
        else
            echo "DHCPv4 is already enabled (ignore not set to 1)"
            logger "DHCPv4 is already enabled (ignore not set to 1)"
        fi

        # Enable DHCPv6
        uci get dhcp.lan.dhcpv6 &> /dev/null
        if [ $? -eq 0 ] && [ "$(uci get dhcp.lan.dhcpv6)" = "disabled" ]; then
            uci set dhcp.lan.dhcpv6='server'  # Set to server to enable DHCPv6
            uci commit dhcp
            /etc/init.d/dnsmasq reload
            echo "DHCPv6 enabled"
            logger "DHCPv6 enabled"
        else
            echo "DHCPv6 is already enabled"
            logger "DHCPv6 is already enabled"
        fi

        # Enable RA (Router Advertisement)
        uci get dhcp.lan.ra &> /dev/null
        if [ $? -eq 0 ] && [ "$(uci get dhcp.lan.ra)" = "disabled" ]; then
            uci set dhcp.lan.ra='server'  # Set to server to enable RA
            uci commit dhcp
            /etc/init.d/network reload
            /etc/init.d/dnsmasq reload
            echo "RA enabled"
            logger "RA enabled"
        else
            echo "RA is already enabled"
            logger "RA is already enabled"
        fi

    elif [ "$state" = "BACKUP" ]; then
        echo "Keepalived state is BACKUP, disabling DHCP and RA"
        logger "Keepalived state is BACKUP, disabling DHCP and RA"

        # Disable DHCPv4
        uci get dhcp.lan.ignore &> /dev/null
        if [ $? -ne 0 ] || [ "$(uci get dhcp.lan.ignore)" != "1" ]; then
            uci set dhcp.lan.ignore='1'  # Set to 1 to disable DHCPv4
            uci commit dhcp
            /etc/init.d/dnsmasq reload
            echo "DHCPv4 disabled"
            logger "DHCPv4 disabled"
        else
            echo "DHCPv4 is already disabled (ignore is set to 1)"
            logger "DHCPv4 is already disabled (ignore is set to 1)"
        fi

        # Disable DHCPv6
        uci get dhcp.lan.dhcpv6 &> /dev/null
        if [ $? -eq 0 ] && [ "$(uci get dhcp.lan.dhcpv6)" != "disabled" ]; then
            uci set dhcp.lan.dhcpv6='disabled'  # Set to disabled to disable DHCPv6
            uci commit dhcp
            /etc/init.d/dnsmasq reload
            echo "DHCPv6 disabled"
            logger "DHCPv6 disabled"
        else
            echo "DHCPv6 is already disabled"
            logger "DHCPv6 is already disabled"
        fi

        # Disable RA
        uci get dhcp.lan.ra &> /dev/null
        if [ $? -eq 0 ] && [ "$(uci get dhcp.lan.ra)" != "disabled" ]; then
            uci set dhcp.lan.ra='disabled'  # Set to disabled to disable RA
            uci commit dhcp
            /etc/init.d/network reload
            /etc/init.d/dnsmasq reload
            echo "RA disabled"
            logger "RA disabled"
        else
            echo "RA is already disabled"
            logger "RA is already disabled"
        fi

    else
        echo "Unknown Keepalived state: $state, skipping DHCP adjustment"
        logger "Unknown Keepalived state: $state, skipping DHCP adjustment"
    fi
}

# Execute the state check function
check_keepalived_state
