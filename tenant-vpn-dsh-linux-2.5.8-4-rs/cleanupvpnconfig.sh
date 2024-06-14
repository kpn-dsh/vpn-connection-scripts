#!/bin/bash
BASE_DIR=/tmp/kafka

DNS_CLUSTER_IP="$1"

OS=$(uname)
if [ "$OS" = "Linux" ] ; then
    echo "cleaning up platform DNS entries in /etc/resolv.conf"
    sed -i "/nameserver ${DNS_CLUSTER_IP}/d" /etc/resolv.conf
elif [ "$OS" = "Darwin" ] ; then
    # search the current network service and select the first output line (network service name)
    CURRENT_NETWORK_SERVICE=$(./osx_currentnetworkservice.sh | sed -n 1p)
    echo "cleaning up platform DNS entries in network service $CURRENT_NETWORK_SERVICE"
    # remove DC/OS DNS entry from current DNS entries
    DNS_ENTRIES=$(/usr/sbin/networksetup -getdnsservers "$CURRENT_NETWORK_SERVICE")
    if [[ "$DNS_ENTRIES" == "${DNS_CLUSTER_IP}" ]] ; then
      NEW_DNS_ENTRIES="Empty"
    else
      NEW_DNS_ENTRIES=$(echo "$DNS_ENTRIES" | tr ' ' '\n' | sed -e "/${DNS_CLUSTER_IP}/d" | tr '\n' ' ')
    fi
    /usr/sbin/networksetup -setdnsservers "$CURRENT_NETWORK_SERVICE" "$NEW_DNS_ENTRIES"
fi

echo "Cleaning up Kafka configuration directory"
rm -rf $BASE_DIR
