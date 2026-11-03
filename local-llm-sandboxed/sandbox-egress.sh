#!/bin/sh
set -eu
iptables -N SANDBOX-EGRESS 2>/dev/null || true
iptables -F SANDBOX-EGRESS
iptables -A SANDBOX-EGRESS -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
iptables -A SANDBOX-EGRESS -d 172.16.0.0/12 -j RETURN
iptables -A SANDBOX-EGRESS -d 100.64.0.0/10 -j RETURN
iptables -A SANDBOX-EGRESS -j DROP
iptables -C DOCKER-USER -s 172.30.70.10/32 -j SANDBOX-EGRESS || iptables -I DOCKER-USER 1 -s 172.30.70.10/32 -j SANDBOX-EGRESS
iptables -C DOCKER-USER -s 172.19.0.250/32 -j SANDBOX-EGRESS || iptables -I DOCKER-USER 1 -s 172.19.0.250/32 -j SANDBOX-EGRESS
iptables -N SANDBOX-INPUT 2>/dev/null || true
iptables -F SANDBOX-INPUT
iptables -A SANDBOX-INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A SANDBOX-INPUT -j DROP
iptables -C INPUT -s 172.30.70.10/32 -j SANDBOX-INPUT || iptables -I INPUT 1 -s 172.30.70.10/32 -j SANDBOX-INPUT
iptables -C INPUT -s 172.19.0.250/32 -j SANDBOX-INPUT || iptables -I INPUT 1 -s 172.19.0.250/32 -j SANDBOX-INPUT
