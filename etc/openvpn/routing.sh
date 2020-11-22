#!/bin/bash

VPNIF="tun0"
VPNUSER="vpn"
GATEWAYIP=$(ifconfig $VPNIF | egrep -o '([0-9]{1,3}\.){3}[0-9]{1,3}' | egrep -v '255|(127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})' | tail -n1)
if [[ `ip rule list | grep -c 0x1` == 0 ]]; then
ip rule add from all fwmark 0x1 lookup $VPNUSER
fi
ip route replace default via $GATEWAYIP table $VPNUSER
ip route append default via 127.0.0.1 dev lo table $VPNUSER
ip route flush cache

# run update-resolv-conf script to set VPN DNS
#/etc/openvpn/update-resolv-conf
