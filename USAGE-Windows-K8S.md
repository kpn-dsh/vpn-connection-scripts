# Instructions how to configure VPN for Windows

## Intro

Use the `./dsh-vpn.ps1` powershell script for Windows. This is a wrapper script around `stunnel`, `openvpn` and `openssl`.

## Client Requirements

- OpenVPN tested with [2.4.x] (can be downloaded from www.openvpn.net)
- OpenSSL hard requirement >= 1.0.0 (command: openssl version)
- Stunnel tested with 5.44 and 5.56 (can be downloaded from www.stunnel.org)

## Notes

- Requires the tenant to have opened the port **1194** if they are behind a firewall.
- Requires the tenant to know the VPN password which can be retrieved through the DSH Console->Secrets
- Requires the tenant to know the tenant name, environment on which it runs and what the DNS suffix is.
- For platforms with releases >= DSH-65

## Set up

1. Unzip the package in a folder on your machine
2. Configure your VPN connection:

   `./dsh-vpn.ps1 create`

   Enter your:
   - Tenant name (in lowercase)
   - Environment
   - DNS suffix
   - Cluster DNS IP
   - VPN User [=admin]
   - VPN Password

   **You can derive the environment and the DNS suffix by looking at the DSH Console's URL:** `https://console.<env>.<dns-suffix>`

   >REMARK: this step needs to be done only once

4. Set up VPN connection:

   `./dsh-vpn.ps1 connect`

   > Proof that VPN connection is setup correctly is that the stunnel icon and OpenVPN icon is showing in the Windows background processes (typically in the right lower corner).

5. Terminate the VPN connection:

   `./dsh-vpn.ps1 disconnect`

## Testing DNS resolution

### Working

```sh
# On Windows
nslookup vpn.<tenant>.marathon.mesos
Server:  ttrouter
Address:  192.168.1.1 # local router

Non-authoritative answer:
Name:    vpn.<tenant>.marathon.mesos
Address:  92.242.132.16 # random public IP
```

## Other useful commands

- the delete the tenant VPN settings for 1 particular tenant:
`./dsh-vpn.ps1 clean`
- the delete all the VPN settings and clear the ${HOME}/.vpn directory:
`./dsh-vpn.ps1 purge`
- the view the config files and open the directory where they are located:
`./dsh-vpn.ps1 config`
- update the CA certificate
`./dsh-vpn.ps1 update-ca`

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
5. AUTH: Received control message: AUTH_FAILED
   - The authentication has failed, possibly you have the wrong user/password configured or they have changed.
6. Script returns UnauthorizedAccess
   - You must allow the script to run. Open an Powershell window in Administrator mode and run `Set-ExecutionPolicy ByPass`
   - Different approach not using 'Bypass', see https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-executionpolicy?view=powershell-7#example-7--unblock-a-script-to-run-it-without-changing-the-execution-policy
7. Can't setup VPN Connection
    - with every DSH relaunch, CA's are renewed thus the local CA needs to be updated by running  ./dsh-vpn.ps1 update-ca

