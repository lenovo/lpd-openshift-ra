#!/bin/bash
GENPASSWORD=`gettab key="nimble" passwd.password`
echo "Appliance MAC Addresses:"
rinv hosts mac
echo IMM info:
for node in `nodels hosts,-ipmi.bmcid= ipmi.bmcid|awk '{print $2}'`; do
    ip=$(grep -B8 $node /var/lib/dhcpd/dhcpd.leases|grep lease|awk '{print $2}'|tail -n 1)
    nodename=$(nodels ipmi.bmcid=$node)
    echo $nodename: $node "($ip)"
done
echo /etc/hosts:
cat /etc/hosts
