#!/bin/bash

export INTERFACE="tun0"
export VPNUSER="vpn"
export LOCALIP="192.168.1.30"
export NETIF="enp1s0"

# flushes all the iptables rules, if you have other rules to use then add them into the script
iptables -F -t nat
iptables -F -t mangle
iptables -F -t filter

# mark packets from $VPNUSER
iptables -t mangle -A OUTPUT -j CONNMARK --restore-mark
iptables -t mangle -A OUTPUT ! --dest $LOCALIP -m owner --uid-owner $VPNUSER -j MARK --set-mark 0x1
iptables -t mangle -A OUTPUT --dest $LOCALIP -p udp --dport 53 -m owner --uid-owner $VPNUSER -j MARK --set-mark 0x1
iptables -t mangle -A OUTPUT --dest $LOCALIP -p tcp --dport 53 -m owner --uid-owner $VPNUSER -j MARK --set-mark 0x1
iptables -t mangle -A OUTPUT ! --src $LOCALIP -j MARK --set-mark 0x1
iptables -t mangle -A OUTPUT -j CONNMARK --save-mark

# allow responses
iptables -A INPUT -i $INTERFACE -m conntrack --ctstate ESTABLISHED -j ACCEPT

# Allow TCP port 59234
iptables -A INPUT -i $INTERFACE -p tcp --dport 59234 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o $INTERFACE -p tcp --sport 59234 -m state --state NEW,ESTABLISHED -j ACCEPT

# block everything incoming on $INTERFACE to prevent accidental exposing of ports
iptables -A INPUT -i $INTERFACE -j ACCEPT


# let $VPNUSER access lo and $INTERFACE
iptables -A OUTPUT -o lo -m owner --uid-owner $VPNUSER -j ACCEPT
iptables -A OUTPUT -o $INTERFACE -m owner --uid-owner $VPNUSER -j ACCEPT

# all packets on $INTERFACE needs to be masqueraded
iptables -t nat -A POSTROUTING -o $INTERFACE -j MASQUERADE

# Start routing script
/etc/openvpn/routing.sh

exit 0
