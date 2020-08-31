# Instructions how to configure VPN for Linux/MacOS

## Intro

Use the `./dsh-vpn.sh` shell script for MacOS and Linux. This is a wrapper script around `stunnel`, `openvpn` and `openssl`. 


## Client Version Requirements

- OpenVPN tested with [2.4.x - 3.0.0] (command: openvpn --version)
- OpenSSL hard requirement >= 1.0.0 (command: openssl version)
- stunnel tested with 5.44 and 5.56 (command: stunnel -version)

## Notes

- Requires the tenant to have opened the port **1194** if they are behind a firewall.
- Requires the tenant to know the VPN password which can be retrieved through the DSH Console->Secrets
- Requires the tenant to know the tenant name, environment on which it runs and what the DNS suffix is.
- For platforms with releases >= DSH-65



## Set up
1. Untar the package in a folder on your machine
2. Initialize basic configuration.This will create a directory under ${HOME}/.vpn/ where all the configuration files for the VPN will reside: 

	`./dsh-vpn.sh init `

>REMARK: this step needs to be done only once

3. Configure your VPN connection: 

	`./dsh-vpn.sh create`
 	
	Enter your:
	- Tenant name (in lowercase)
	- Environment 
	- DNS suffix 
	- VPN User [=admin]
	- VPN Password

**You can derive the environment and the DNS suffix by looking at the DSH Console's URL:**
  `https://console.<env>.<dns-suffix>`

>REMARK: this step needs to be done only once

4. Set up VPN connection: 

	`./dsh-vpn.sh connect <tenant-name> <env>`
5. (optional) If you want to run your application locally on your local PC and connect to DSH, you need to manually a script that will retrieve and configure the Kafka security settings: 

	`./getjks.sh`


## Testing DNS resolution

### Working

```sh
# On Linux / Mac OS
> dig vpn.<tenant>.marathon.mesos
; <<>> DiG 9.11.21-RedHat-9.11.21-1.fc32 <<>>
vpn.<tenant>.marathon.mesos
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 9658
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 0
;; QUESTION SECTION:
;vpn.<tenant>.marathon.mesos. IN A
;; ANSWER SECTION:
vpn.<tenant>.marathon.mesos. 60 IN A 10.142.12.5
;; Query time: 67 msec
;; SERVER: 198.51.100.1#53(198.51.100.1)
;; WHEN: Wed Aug 12 15:33:02 BST 2020
;; MSG SIZE rcvd: 58
```


### Failing

```sh
> dig vpn.<tenant>.marathon.mesos # use nslookup for Windows
; <<>> DiG 9.11.21-RedHat-9.11.21-1.fc32 <<>>
vpn.<tenant>.marathon.mesos
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 38763
;; flags: qr rd ra ad; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1
;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 512
;; QUESTION SECTION:
;vpn.<tenant>.marathon.mesos. IN A
;; AUTHORITY SECTION:
. 86398 IN SOA a.root-servers.net. nstld.verisign-grs.com. 2020081200
1800 900 604800 86400
;; Query time: 62 msec
;; SERVER: 8.8.8.8#53(8.8.8.8)
;; WHEN: Wed Aug 12 15:34:46 BST 2020
;; MSG SIZE rcvd: 128
```

## Other useful commands

- To stop the VPN Connection, press CTRL+C
- the delete the tenant VPN settings for 1 particular tenant: 
`./dsh-vpn.sh clean`
- the delete all the VPN settings and clear the ${HOME}/.vpn directory:
`./dsh-vpn.sh purge`


## Commons Issues

1. TLS Error: TLS handshake failed. Re fetch the CA
    - This is an indication that stunnel is not working properly, so:
        i. Re download the CA as it has changed
        ii. Ensure you do not have any https:// in the stunnel.conf
        iii. Restart stunnel
2. System.IO.IOException: The process cannot access the file 'stunnel.log'
   - This is an indication clean up was performed while stunnel or openvpn where running or an editor or other tool had the files open.
3. [!] bind: Address already in use (WSAEADDRINUSE) (10048) [!] Error binding service [openvpn] to 127.0.0.1:1195
   - This is an indication that stunnel has crashed badly or you have another service using this port. Easiest fix is to restart your PC. Otherwise you need to free or switch to a different port.
4. The remote server returned an error: (502)
   - This usually means that the CA server is down/starting. Try downloading the CA using your browser. When it starts working clean and and re init the tenant. If the issue persists contact support.
5. No configuration yet for <tenantname> <env>. -- Even when it exists.
   - This can happen if the script has different user during execution, for example if ran with sudo elevation
6. AUTH: Received control message: AUTH_FAILED
   - The authentication has failed, possibly you have the wrong user/password configured or they have changed.


