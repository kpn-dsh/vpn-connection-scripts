#!/bin/bash
CONFIG_DIR=/tmp/kafka/config
conffile=$CONFIG_DIR/kafkasec.properties
kafka_client_conffile=$CONFIG_DIR/client.conf

if [ -z "$1" ]
then
  echo "Tenant name not set; give tenant name as an argument to this script (sudo ./getjks.sh <tenant-name-lower-case>)."
  exit 1
fi

#wget vpn.$1.marathon.mesos:8888 -O $CONFIG_DIR/ca.crt
wget vpn.$1.marathon.mesos:8889 -O $CONFIG_DIR/keystore.jks
wget vpn.$1.marathon.mesos:8890 -O $CONFIG_DIR/truststore.jks

(
echo "KAFKA_SSL_KEYSTORE_LOCATION=$CONFIG_DIR/keystore.jks"
echo "KAFKA_SSL_TRUSTSTORE_LOCATION=$CONFIG_DIR/truststore.jks"
) >> "$conffile"

# All relevant information to be able to connect securely to kafka is now in the $conffile
cat $conffile

# ----
# try the configuration:
# Load information in the file
source $conffile

# Export the information in environment variables
export KAFKA_SECURITY_PROTOCOL=${KAFKA_SECURITY_PROTOCOL}
export KAFKA_SSL_TRUSTSTORE_LOCATION=${KAFKA_SSL_TRUSTSTORE_LOCATION}
export KAFKA_SSL_TRUSTSTORE_PASSWORD=${KAFKA_SSL_TRUSTSTORE_PASSWORD}
export KAFKA_SSL_KEYSTORE_LOCATION=${KAFKA_SSL_KEYSTORE_LOCATION}
export KAFKA_SSL_KEYSTORE_PASSWORD=${KAFKA_SSL_KEYSTORE_PASSWORD=}
export KAFKA_SSL_KEY_PASSWORD=${KAFKA_SSL_KEY_PASSWORD=}
export KAFKA_CLIENT_CONFIG=${kafka_client_conffile}

# Write kafka client config file
cat > "$kafka_client_conffile" <<EOF
security.protocol=SSL
ssl.truststore.location=$CONFIG_DIR/truststore.jks
ssl.truststore.password=${KAFKA_SSL_TRUSTSTORE_PASSWORD}
ssl.keystore.location=$CONFIG_DIR/keystore.jks
ssl.keystore.password=${KAFKA_SSL_KEYSTORE_PASSWORD}
ssl.key.password=${KAFKA_SSL_KEY_PASSWORD}
EOF

sudo "${HOME}"/.vpn/convertjkstocerts.sh $CONFIG_DIR ${KAFKA_SSL_TRUSTSTORE_PASSWORD} ${KAFKA_SSL_KEYSTORE_PASSWORD} ${KAFKA_SSL_KEY_PASSWORD}

echo "KAFKA_CLIENT_CONFIG=$kafka_client_conffile"
export PKI_CONFIG_DIR=CONFIG_DIR


########################
## Tenant configuration
########################

# Use the environment variables in your program
# <YOUR PROGRAM HERE>
# java -cp /opt/bin/kafkaconsumertest-assembly-0.1-SNAPSHOT.jar com.klarrio.topictest.KafkaTopicTest
