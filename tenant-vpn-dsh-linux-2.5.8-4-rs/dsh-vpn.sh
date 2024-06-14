#!/bin/bash
set -m

export PROG_VERSION=1.0.3

function sed_home() {
    echo $(echo $HOME | sed 's_/_\\/_g')
}

function version() {
    echo "dsh-vpn.sh version: ${PROG_VERSION}"
    exit
}

function open_directory() {
    ARG_DIRECTORY=$1
    # Linux
    xdg-open "${ARG_DIRECTORY}" > /dev/null 2> /dev/null || \
    # Darwin
    open "${ARG_DIRECTORY}" > /dev/null 2> /dev/null || \
    # Break glass kind of case
    echo "open the directory: '${ARG_DIRECTORY}'"
}

function config(){
    if [ "$#" == "0" ]; then
        read -p "Tenant": TENANT
        read -p "Environment": ENVIRONMENT
    elif [ "$#" == "2" ]; then
        TENANT="$1"
        ENVIRONMENT="$2"
    else
        echo "Create expects 0 or 2 (tenant, environment) parameters."
        exit 1
    fi
    open_directory "${HOME}/.vpn/${TENANT}/${ENVIRONMENT}/"
}

function logs(){
    if [ "$#" == "0" ]; then
        read -p "Tenant": TENANT
        read -p "Environment": ENVIRONMENT
    elif [ "$#" == "2" ]; then
        TENANT="$1"
        ENVIRONMENT="$2"
    else
        echo "Create expects 0 or 2 (tenant, environment) parameters."
        exit 1
    fi
    open_directory "${HOME}/.vpn/${TENANT}/${ENVIRONMENT}/logs/"
}

function tail_logs(){
    if [ "$#" == "0" ]; then
        read -p "Tenant": TENANT
        read -p "Environment": ENVIRONMENT
    elif [ "$#" == "2" ]; then
        TENANT="$1"
        ENVIRONMENT="$2"
    else
        echo "Create expects 0 or 2 (tenant, environment) parameters."
        exit 1
    fi
    VPN_LOG="${HOME}/.vpn/${TENANT}/${ENVIRONMENT}/logs/openvpn.log"
    STUNNEL_LOG="${HOME}/.vpn/${TENANT}/${ENVIRONMENT}/logs/stunnel.log"
    tail -f -n +1 ${STUNNEL_LOG} ${VPN_LOG}
}

function template_vpn_conf() {
cat << EOF
client
ca #_HOME_#/.vpn/#_TENANT_#/#_ENVIRONMENT_#/ca.crt
dev tun
proto tcp-client
remote 127.0.0.1 1195
nobind
cipher AES-256-CBC
auth-user-pass #_HOME_#/.vpn/#_TENANT_#/#_ENVIRONMENT_#/credentials
log #_HOME_#/.vpn/#_TENANT_#/#_ENVIRONMENT_#/logs/openvpn.log
script-security 3
verb 3
up "#_HOME_#/.vpn/initconfig.sh #_DNS_CLUSTER_IP_#"
down "#_HOME_#/.vpn/cleanupvpnconfig.sh #_DNS_CLUSTER_IP_#"
EOF
}


function template_stunnel_conf() {
cat << EOF
# https://charlesreid1.com/wiki/OpenVPN/Stunnel
# https://www.stunnel.org/static/stunnel.html
client  = yes
debug = 7
pid = #_HOME_#/.vpn/#_TENANT_#/#_ENVIRONMENT_#/stunnel.pid
output = #_HOME_#/.vpn/#_TENANT_#/#_ENVIRONMENT_#/logs/stunnel.log
[openvpn]
Options = all
Options = NO_SSLv3
Options = NO_SSLv3
options = NO_TLSv1
verify = 0
verifyPeer = no
verifyChain = no
CAfile = #_HOME_#/.vpn/#_TENANT_#/#_ENVIRONMENT_#/ca.crt
sni = #_TENANT_#-openvpn.#_ENVIRONMENT_#.#_DNS_SUFFIX_#
connect = #_TENANT_#-openvpn.#_ENVIRONMENT_#.#_DNS_SUFFIX_#:1194
accept  = 127.0.0.1:1195
EOF
}


function help() {
cat << EOF
dsh-vpn.sh,  Version ${PROG_VERSION}

dsh-vpn.sh clean <tenant> <environment>
    Clean up a tenant local configuration

dsh-vpn.sh create <tenant> <environment> <dns-suffix>
dsh-vpn.sh create
  Add a new VPN configuration to your system. If tenant and environment are not provided as arguments, they will be requested interactively.
  You will also need to provide the username and password for the VPN. These can be found on the configuration tab of the VPN container in DC/OS.

dsh-vpn.sh config <tenant> <environment>
dsh-vpn.sh config
  Open the configuration directory of a specific tenant and environment

dsh-vpn.sh logs <tenant> <environment>
dsh-vpn.sh logs
  Open the logs directory of a specific tenant and environment

dsh-vpn.sh tail-logs <tenant> <environment>
dsh-vpn.sh tail-logs
  Tail the logs of stunnel and openvpn in the terminal

dsh-vpn.sh connect <tenant> <environment>
  Connect using openVPN to the given tenant in the given environment. This will also run the getjks logic to obtain a Kafka config.
  Any shell opened after this one will export these Kafka config environment variables, making them available to the session.

dsh-vpn.sh update-ca <tenant> <environment> <dns-suffix>
dsh-vpn.sh update-ca
  Re-downloads the CA for an environment

dsh-vpn.sh disconnect
  kill openvpn and stunnel

dsh-vpn.sh version
    show the version of the dsh-vpn.sh tool

dsh-vpn.sh purge
  Purge the whole ~/.vpn configuration directory
EOF
}


function provide_openvpn() {
    openvpn &> /dev/null
    if [ "$?" == "127" ]; then
        echo "OpenVPN not installed yet. Installing now. (trying sudo)"
        sudo apt install openvpn
    fi
}

function update_bash_file() {
    BASH_FILE=$1
    touch ${HOME}/.vpn/kafka_env
    LINE_PRESENT=$(grep "source ${HOME}/.vpn/kafka_env" ${BASH_FILE}|wc -l)
    if [ "${LINE_PRESENT}" == "0" ];then
        echo "Appending sourcing lines to ${BASH_FILE}."
        echo "" >> ${BASH_FILE}
        echo "# SOURCING VPN Kafka Env variables" >> ${BASH_FILE}
        echo "source ${HOME}/.vpn/kafka_env" >> ${BASH_FILE}
    fi
}


function init() {
  
    provide_openvpn

    # Assume the current directory has the latest *Client* DSH VPN code
    rm -rf /tmp/dsh-tool-vpn
    cp -rf ./ /tmp/dsh-tool-vpn

    mkdir -p ${HOME}/.vpn

    if [ -f ${HOME}/.bashrc ]; then
        update_bash_file "${HOME}/.bashrc"
    elif [ -f ${HOME}/.bash_profile ]; then
        update_bash_file "${HOME}/.bash_profile"
    else
        echo "No bashrc or bash_profile found. To have VPN Kafka Env variables in new terminals, execute:"
        echo "source ${HOME}/.vpn/kafka_env"
    fi

    cp /tmp/dsh-tool-vpn/initconfig.sh ${HOME}/.vpn/
    cp /tmp/dsh-tool-vpn/cleanupvpnconfig.sh ${HOME}/.vpn/
    cp /tmp/dsh-tool-vpn/getjks.sh ${HOME}/.vpn/getjks.sh
    cp /tmp/dsh-tool-vpn/convertjkstocerts.sh ${HOME}/.vpn/convertjkstocerts.sh
    cp /tmp/dsh-tool-vpn/osx_currentnetworkservice.sh ${HOME}/.vpn/osx_currentnetworkservice.sh

    chmod +x ${HOME}/.vpn/*.sh
    chmod -R 700 ~/.vpn
    rm -rf /tmp/dsh-tool-vpn
}

function create() {
    if [ "$#" == "0" ]; then
        read -p "Tenant": TENANT
        read -p "Environment": ENVIRONMENT
        read -p "DNS suffix": DNS_SUFFIX
        read -p "Cluster DNS IP": DNS_CLUSTER_IP
    elif [ "$#" == "4" ]; then
        TENANT="$1"
        ENVIRONMENT="$2"
        DNS_SUFFIX="$3"
        DNS_CLUSTER_IP="$4"
    else
        echo "Create expects 0 or 4 (tenant, environment, DNS suffix, Cluster DNS IP) parameters."
        exit 1
    fi

    init

    if [ -d "${HOME}/.vpn/${TENANT}/${ENVIRONMENT}" ]; then
        echo "Configuration yet for ${TENANT} ${ENVIRONMENT} for already exists. Not creating."
        exit 1
    fi

    read -p "Username [admin]": USERNAME
    read -s -p "Password": PASSWORD
    echo ""

    if [ "${USERNAME}" == "" ]; then
        USERNAME="admin"
    fi

    mkdir -p "${HOME}/.vpn/${TENANT}/${ENVIRONMENT}/logs/"
    touch "${HOME}/.vpn/${TENANT}/${ENVIRONMENT}/logs/openvpn.log" "${HOME}/.vpn/${TENANT}/${ENVIRONMENT}/logs/stunnel.log"

    wget "https://${TENANT}-ca.${ENVIRONMENT}.${DNS_SUFFIX}" -O "${HOME}/.vpn/${TENANT}/${ENVIRONMENT}/ca.crt"
    template_vpn_conf|sed -e "s/#_USERNAME_#/$USERNAME/g"\
                      -e"s/#_HOME_#/$(sed_home)/g"\
                      -e "s/#_TENANT_#/$TENANT/g"\
                      -e "s/#_ENVIRONMENT_#/$ENVIRONMENT/g"\
                      -e "s/#_DNS_CLUSTER_IP_#/${DNS_CLUSTER_IP}/g"\
                      -e "s/#_DNS_SUFFIX_#/$DNS_SUFFIX/g" > "${HOME}/.vpn/${TENANT}/${ENVIRONMENT}/client.conf"
    template_stunnel_conf|sed -e "s/#_USERNAME_#/$USERNAME/g"\
                      -e"s/#_HOME_#/$(sed_home)/g"\
                      -e "s/#_TENANT_#/$TENANT/g"\
                      -e "s/#_ENVIRONMENT_#/$ENVIRONMENT/g"\
                      -e "s/#_DNS_SUFFIX_#/$DNS_SUFFIX/g" > "${HOME}/.vpn/${TENANT}/${ENVIRONMENT}/stunnel.conf"
    printf "${USERNAME}\n${PASSWORD}" > "${HOME}/.vpn/${TENANT}/${ENVIRONMENT}/credentials"

    mkdir "${HOME}/.vpn/${TENANT}/${ENVIRONMENT}/kafka"
    #sed "s/^CONFIG_DIR=.*/CONFIG_DIR=`sed_home`\/.vpn\/${TENANT}\/${ENVIRONMENT}\/kafka/g" ${HOME}/.vpn/getjks.sh > ${HOME}/.vpn/${TENANT}/${ENVIRONMENT}/kafka/getjks.sh

    chmod -R 700 ${HOME}/.vpn/${TENANT}/${ENVIRONMENT}/*
}


function clean() {
    if [ "$#" == "0" ]; then
        read -p "Tenant": TENANT
        read -p "Environment": ENVIRONMENT
    elif [ "$#" == "2" ]; then
        TENANT="$1"
        ENVIRONMENT="$2"
    else
        echo "Create expects 0 or 3 (tenant, environment, platform domain) parameters."
        exit 1
    fi

    if [ ! -d "${HOME}/.vpn/${TENANT}/${ENVIRONMENT}" ]; then
        echo "Configuration yet for ${TENANT} ${ENVIRONMENT} for does not exists. Not cleaning."
        exit 1
    fi

    rm -rf "${HOME}/.vpn/${TENANT}/${ENVIRONMENT}/"
}

function purge() {
    read -p "Are you sure you want to remove completely your ~/.vpn directory? " -n 1 -r
    echo    # (optional) move to a new line
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
        [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1 # handle exits from shell or function but don't exit interactive shell
    fi
    rm -rf ${HOME}/.vpn/
}

function connect() {
    rv=$(which stunnel)
    if [ $? != 0 ]; then
        echo "Can't find stunnel. Please install stunnel first or add to your PATH"
        exit 1
    fi
    
    rv=$(which openvpn) 
    if [ $? != 0 ]; then
        echo "Can't find openvpn. Please install openvpn first or add to your PATH"
        exit 1
    fi

    if [ "$#" != 2 ]; then
        echo "Connect expects 2 (tenant, environment) parameters."
        exit 1
    fi

    init
    TENANT=$1
    ENVIRONMENT=$2

    if [ ! -d "${HOME}"/.vpn/"${TENANT}"/"${ENVIRONMENT}" ]; then
        echo "No configuration yet for ${TENANT} ${ENVIRONMENT}: could not find '${HOME}/.vpn/${TENANT}/${ENVIRONMENT}'"
        echo "Create it first with the create command, using ${TENANT} and ${ENVIRONMENT} as arguments."
        exit 1
    fi

    #extract suffix & update CA
    STUNNEL_CONF="${HOME}/.vpn/${TENANT}/${ENVIRONMENT}/stunnel.conf"
    DNS_SUFFIX=$(grep sni $STUNNEL_CONF | cut -d '.' -f3-)
    echo "dns_suffix: $DNS_SUFFIX"
    update_ca ${TENANT} ${ENVIRONMENT} ${DNS_SUFFIX}    

    if [ "$EUID" != "0" ]; then
        echo "stunnel requires root permissions. (trying sudo)"
        sudo stunnel ~/.vpn/${TENANT}/${ENVIRONMENT}/stunnel.conf &
    else
        stunnel ~/.vpn/${TENANT}/${ENVIRONMENT}/stunnel.conf &
    fi

    if [ "$EUID" != "0" ]; then
        echo "OpenVPN requires root permissions. (trying sudo)"
        sudo openvpn ~/.vpn/${TENANT}/${ENVIRONMENT}/client.conf &
    else
        openvpn ~/.vpn/${TENANT}/${ENVIRONMENT}/client.conf &
    fi

    sudo mkdir -p /tmp/kafka/config
    sudo chmod -R 700  /tmp/kafka

    for I in 1 2 3 4 5
    do
	echo "Trying to connect to VPN server..."
    
	rv=$(wget vpn."${TENANT}".marathon.mesos:8888 -o /tmp/vpn.log > /dev/null 2> /dev/null)
	if [ "$?" == "0" ]
	then
		break
	fi
    sleep 5
	
	if [ "$I" == "5" ] 
	then
		echo "Failed to setup VPN connection..."
		exit 1
	fi	
    done

    sudo "${HOME}"/.vpn/getjks.sh "${TENANT}"
    sudo chown -R "${USER}": /tmp/kafka

    echo "Writing config to env variables and ${HOME}/.vpn/kafka_env"
    cp -r /tmp/kafka/config/* "${HOME}"/.vpn/"${TENANT}"/"${ENVIRONMENT}"/kafka/
    sed 's/^/export /' "${HOME}"/.vpn/"${TENANT}"/"${ENVIRONMENT}"/kafka/kafkasec.properties > "${HOME}"/.vpn/kafka_env
    echo "Connect completed..."
    echo "   use \"$0 tail-logs '${TENANT}' '${ENVIRONMENT}'\" to see the logs"
    echo "   use \"$0 disconnect\" to stop the vpn conenction"
}

function update_ca() {
    if [ "$#" == "0" ]; then
        read -p "Tenant": TENANT
        read -p "Environment": ENVIRONMENT
        read -p "DNS suffix": DNS_SUFFIX
    elif [ "$#" == "3" ]; then
        TENANT="$1"
        ENVIRONMENT="$2"
        DNS_SUFFIX="$3"
    else
        echo "Create expects 0 or 3 (tenant, environment, DNS suffix) parameters."
        exit 1
    fi
    mkdir -p ${HOME}/.vpn/${TENANT}/${ENVIRONMENT}
    wget https://${TENANT}-ca.${ENVIRONMENT}.${DNS_SUFFIX} -O ${HOME}/.vpn/${TENANT}/${ENVIRONMENT}/ca.crt
}

function disconnect() {
    stop_command_silently openvpn
    stop_command_silently stunnel
}

function stop_command_silently() {
    command=$1
    sudo pkill $command > /dev/null 2> /dev/null ||
    sudo pkill -9 $command > /dev/null 2> /dev/null ||
    true > /dev/null 2> /dev/null
}


if [ "$1" == "create" ]; then
    create "${@:2}"
elif [ "$1" == "config" ]; then
    config "${@:2}"
elif [ "$1" == "logs" ]; then
    logs "${@:2}"
elif [ "$1" == "tail-logs" ]; then
    tail_logs "${@:2}"
elif [ "$1" == "connect" ]; then
    disconnect
    connect "${@:2}"
elif [ "$1" == "disconnect" ]; then
    disconnect
elif [ "$1" == "clean" ]; then
    clean "${@:2}"
elif [ "$1" == "version" ]; then
    version
elif [ "$1" == "purge" ]; then
    purge
elif [ "$1" == "update-ca" ]; then
    update_ca "${@:2}"
elif [ "$1" == "help" ]; then
    help
else
    echo "Unknown Command '$1'. Known Commands: create, connect, disconnect, clean, purge, version, config, logs, tail-logs, update-ca, help"
    exit 1
fi
