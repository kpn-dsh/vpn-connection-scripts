#!/bin/bash
CONFIG_DIR=/tmp/kafka/config
conffile=$CONFIG_DIR/kafkasec.properties

DNS_CLUSTER_IP="$1"

write_kafka_secconf_to_file() {
  if [ ! -z "$OPENVPN_KAFKA_SSL_TRUSTSTORE_PASSWORD" ] ; then
    echo "writing Kafka security configuration to $conffile"
    echo "KAFKA_SECURITY_PROTOCOL=${OPENVPN_KAFKA_SECURITY_PROTOCOL}" >> "$conffile"
    echo "KAFKA_SSL_TRUSTSTORE_PASSWORD=${OPENVPN_KAFKA_SSL_TRUSTSTORE_PASSWORD}" >> "$conffile"
    echo "KAFKA_SSL_KEYSTORE_PASSWORD=${OPENVPN_KAFKA_SSL_KEYSTORE_PASSWORD}" >> "$conffile"
    echo "KAFKA_SSL_KEY_PASSWORD=${OPENVPN_KAFKA_SSL_KEY_PASSWORD}" >> "$conffile"
    echo "KAFKA_GROUP_ID=${OPENVPN_KAFKA_GROUP_ID}" >> "$conffile"
    echo "PKI_CONFIG_DIR=${CONFIG_DIR}" >> "$conffile"
  fi
}

#Set DNS configuration based on the OS
OS=$(uname)
if [ "$OS" = "Darwin" ] ; then
    echo "configuring DNS for OSX"
    # search the current network service and select the first output line (network service name)
    CURRENT_NETWORK_SERVICE=$(./osx_currentnetworkservice.sh | sed -n 1p)
    echo "configuring DNS for network service $CURRENT_NETWORK_SERVICE"
    # add DC/OS DNS entry to current DNS entries as the first entry
    DNS_ENTRIES=$(/usr/sbin/networksetup -getdnsservers "$CURRENT_NETWORK_SERVICE")
    if [[ "$DNS_ENTRIES" == "There aren't any DNS Servers set"* ]] ; then
      NEW_DNS_ENTRIES="${DNS_CLUSTER_IP}"
    else
      NEW_DNS_ENTRIES=$(echo "$DNS_ENTRIES" | tr '\n' ' ' | sed -e "s/^/${DNS_CLUSTER_IP} /")
    fi
    /usr/sbin/networksetup -setdnsservers "$CURRENT_NETWORK_SERVICE" "$NEW_DNS_ENTRIES"
else
    echo "configuring DNS for Linux"
    echo "configuring DNS in /etc/resolv.conf"
    sed -i "/nameserver/ i\nameserver ${DNS_CLUSTER_IP}" /etc/resolv.conf
fi

mkdir -p $CONFIG_DIR
write_kafka_secconf_to_file
