#!/bin/bash
if [ $# -ne 4 ]; then
  echo "Usage: $0 <CONFIG_DIR> <KAFKA_SSL_TRUSTSTORE_PASSWORD> <KAFKA_SSL_KEYSTORE_PASSWORD> <KAFKA_SSL_KEY_PASSWORD>. This script should be triggered from getjks.sh."
  exit 1
fi

CONFIG_DIR=$1
KAFKA_SSL_TRUSTSTORE_PASSWORD=$2
KAFKA_SSL_KEYSTORE_PASSWORD=$3
KAFKA_SSL_KEY_PASSWORD=$4

TRUSTSTORE=$CONFIG_DIR/truststore.jks
KEYSTORE=$CONFIG_DIR/keystore.jks

echo
echo "Converting JKS files to PEM files"

# Convert the JKS  key to a .key file in pem format, also add the KAFKA_SSL_KEY_PASSWORD for the server key
keytool -importkeystore -srckeystore $KEYSTORE -srcstorepass $KAFKA_SSL_KEYSTORE_PASSWORD -srcstoretype JKS -destkeystore $KEYSTORE.p12 -deststoretype PKCS12 -deststorepass $KAFKA_SSL_KEYSTORE_PASSWORD -srcalias server -srckeypass $KAFKA_SSL_KEY_PASSWORD -noprompt

openssl pkcs12 -in $KEYSTORE.p12 -nodes -nocerts -out $CONFIG_DIR/client.key -passin pass:$KAFKA_SSL_KEYSTORE_PASSWORD -passout pass:$KAFKA_SSL_KEY_PASSWORD

# Convert the JKS ca certificate to a .crt file in pem format
keytool -export -alias server -keystore $KEYSTORE -file $CONFIG_DIR/client.crt -storepass $KAFKA_SSL_KEYSTORE_PASSWORD -noprompt

openssl x509 -in $CONFIG_DIR/client.crt -out $CONFIG_DIR/client.pem -outform PEM

# Convert the JKS ca certificate to a .crt file in pem format
keytool -export -alias ca -keystore $TRUSTSTORE -file $CONFIG_DIR/ca.crt -storepass $KAFKA_SSL_TRUSTSTORE_PASSWORD -noprompt

openssl x509 -in $CONFIG_DIR/ca.crt -out $CONFIG_DIR/ca.pem -outform PEM

# Remove tmp files
rm $KEYSTORE.p12
rm $CONFIG_DIR/client.crt
rm $CONFIG_DIR/ca.crt


echo "Conversion complete"
echo
echo "PKI_CONFIG_DIR=$CONFIG_DIR"
echo

