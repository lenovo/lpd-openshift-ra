#!/bin/bash
function current_timestamp {
  d=`date +%y-%m-%d:%H:%M:%S`
  echo $d
}

export PATH=/opt/xcat/bin:/opt/xcat/sbin:/opt/confluent/bin:$PATH
service dhcpd stop
rm -rf /var/lib/dhcpd/dhcpd.leases > /dev/null
touch /var/lib/dhcpd/dhcpd.leases
rm -rf /var/run/confluent/pid > /dev/null
rm -rf /var/run/syslogd.pid > /dev/null
ip route flush cache  > /dev/null
ip route flush type cache  > /dev/null
rm -f ~/.ssh/known*
rm -rf /var/log/confluent/consoles/*

# Prompt for which interface to use for the deployment
cd `dirname $0`
if [ ! -r /etc/profile.d/xcat.sh ]; then
        echo "xCAT must be installed prior to running this script"
fi
. /etc/profile.d/xcat.sh
/lci/utils/runxcatd

dnic=`gettab key=targetinterface site.value`
if [ "$dnic" = "" ]; then
  NICSET=0
else
  NICSET=1
fi
# echo $dnic
# echo $NICSET
while [ $NICSET = 0 ]; do
        for nic in $(ip link|grep -v master|egrep '^[0-9]'|grep LOWER_UP|grep -v LOOPBACK|cut -d: -f 2); do
                echo $nic:
                ip addr show dev $nic|tail -n +2
        done
        echo -n "Select a deployment NIC from above (e.g. $nic): "
        read dnic
        for nic in $(ip link|grep -v master|egrep '^[0-9]'|grep LOWER_UP|grep -v LOOPBACK|cut -d: -f 2); do
                if [ $dnic = $nic ]; then
                        NICSET=1
                fi
        done
done

echo -n "Automation starts at "
current_timestamp

date=`date +%y-%m-%d:%H:%M:%S`
mkdir -p /lci/log/$date
date=$date ./utils/clrxcat.sh
#service dnsmasq stop
service dnsmasq start
#service httpd stop
service httpd restart
service confluent stop
service confluent start
export dnic

# First let's generate a new ULA, and apply it to the deployment interface
ULA=$(. /opt/xcat/share/xcat/scripts/genula.sh|sed -e 's!:/48!!')
#GENPASSWORD=$(/lci/genpassword.py)
#GENPASSWORD='Passw0rd!'
#GENPASSWORD='Th1nkAg!le'
#echo "Unique password for this configuration will be: $GENPASSWORD"
rm -f /etc/sysconfig/network-scripts/ifcfg-$dnic
touch  /etc/sysconfig/network-scripts/ifcfg-$dnic
#grep -v IPV6ADDR /etc/sysconfig/network-scripts/ifcfg-$dnic | grep -v ^DEVICE| grep -v IPV6INIT| grep -v HWADDR | grep -v ONBOOT |grep -v BOOTPROTO> /etc/sysconfig/network-scripts/ifcfg-$dnic.new
echo IPV6ADDR=${ULA}40::dead:beef/64 >> /etc/sysconfig/network-scripts/ifcfg-$dnic.new
echo IPV6ADDR_SECONDARIES=${ULA}40::dead:beef/64 >> /etc/sysconfig/network-scripts/ifcfg-$dnic.new
echo BOOTPROTO=none >> /etc/sysconfig/network-scripts/ifcfg-$dnic.new
echo ONBOOT=yes >> /etc/sysconfig/network-scripts/ifcfg-$dnic.new
echo IPADDR=172.20.243.1 >> /etc/sysconfig/network-scripts/ifcfg-$dnic.new
echo IPV6INIT="yes" >>  /etc/sysconfig/network-scripts/ifcfg-$dnic.new
echo NETMASK=255.255.0.0 >> /etc/sysconfig/network-scripts/ifcfg-$dnic.new
echo BOOTPROTO=none >> /etc/sysconfig/network-scripts/ifcfg-$dnic.new
echo ARPCHECK=no >> /etc/sysconfig/network-scripts/ifcfg-$dnic.new
echo DEVICE='"'$dnic'"' >> /etc/sysconfig/network-scripts/ifcfg-$dnic.new
mv /etc/sysconfig/network-scripts/ifcfg-$dnic.new /etc/sysconfig/network-scripts/ifcfg-$dnic
sysctl -w net.ipv6.conf.$dnic.accept_ra=0
ifdown $dnic
if ! ifup $dnic; then
	echo "Error on networking, cannot continue"
	sleep 86400
	exit
fi
#service network restart

function loop {
i=1
j=$1
msg=" ${2}"
j=$((j*10))
LOOP_CHAR=/

while :; do
  if [ "$LOOP_CHAR" = "/" ]; then
    echo -ne "/${msg}\r"
    LOOP_CHAR=-
  elif [ "$LOOP_CHAR" = "-" ]; then
    echo -ne "-${msg}\r"
    LOOP_CHAR='\'
  elif [ "$LOOP_CHAR" = "\\" ]; then
    printf "\\%s${msg}\r" " "
    LOOP_CHAR='|'
  elif [ "$LOOP_CHAR" = "|" ]; then
    echo -ne "|${msg}\r"
    LOOP_CHAR=/
  fi
  sleep 0.1
  if [ "$i" == "$j" ]; then
    break
  fi
  i=$((i+1))
done
}

echo "Waiting 1 minute in case of spanning tree"
loop 5
echo "... Done"

PRODNAME=`gettab key=prodname site.value`
PRODTYPE=`gettab key=prodtype site.value`
FIRST_NODE=`gettab key=firstnode site.value`
LAST_NODE=`gettab key=lastnode site.value`
BOND_NET=`gettab key=bondnet site.value`
GENPASSWORD=`gettab key=genpassword site.value`
if [ "$GENPASSWORD" = "" ]; then
  GENPASSWORD='Th1nkAg!le'
fi
echo "Unique password for this configuration will be: $GENPASSWORD"
# OS_TYPE=`gettab key=ostype site.value`
# if [ "$OS_TYPE" = "rhela7" ]; then
#  ostype=rhela7-x86_64-install-compute
# elif [ "$OS_TYPE" = "rhels7" ]; then
#  ostype=rhels7.3-x86_64-install-compute
# fi

for i in `seq 1 200`; do { ping -c 1 172.20.250.$i >/dev/null & }; disown; done > /dev/null 2>&1 
makenetworks
chtab key=domain site.value=${PRODNAME}
chtab key=dhcplease site.value=600
chtab key=ulaprefix site.value=$ULA
chtab net=172.20.0.0 networks.dynamicrange=172.20.250.1-172.20.250.200
#chtab net=172.20.0.0 networks.dynamicrange=172.20.250.1-172.20.250.200 networks.vlanid=4001
chtab key=dhcpinterfaces site.value=$dnic
chtab key=bondnet site.value=172.30.4
chtab key=vmware passwd.username=root passwd.password=$GENPASSWORD
chtab key=vcenter passwd.username=Administrator@thinkagile.lenovo.local passwd.password=$GENPASSWORD
chtab key=lxca passwd.username=admin passwd.password=$GENPASSWORD
chtab key=nimble passwd.username=admin passwd.password=$GENPASSWORD
chtab key=switch passwd.username=admin passwd.password=$GENPASSWORD
# chtab key=numnodes site.value=$NODES_TO_CONFIGURE
chtab key=ipmi passwd.username=USERID passwd.password=$GENPASSWORD
chtab key=system passwd.username=root passwd.password=$GENPASSWORD
chtab key=osuser1 passwd.username=lukasz passwd.password=luKasz1@3
chtab key=osuser2 passwd.username=atomic passwd.password=@Tom1cHost
chtab key=master site.value=172.20.243.1
chtab key=nameservers site.value=172.20.243.1
NODES_TO_BACKUP=2
chtab key=numbackupnodes site.value=$NODES_TO_BACKUP
makedhcp -n
service dhcpd restart
makedhcp -d hosts > /dev/null 2>&1
#ip addr add dev $dnic 10.0.0.6/29
#ip addr add dev $dnic 192.168.70.126/24
for tabfile in tabfiles/*; do
	tabrestore $tabfile
done

#nodegrpch hosts nodehm.mgt=ipmi ipmi.bmc='|'${ULA}40::'3:($1)|'
#nodegrpch hosts nodehm.mgt=ipmi ipmi.bmc='|'${ULA}40::'3:($1)|' ipmi.password=$GENPASSWORD ipmi.username=USERID

config_file=`gettab key=configfile site.value`
echo config_file=$config_file

numnodes=0
i=0
first_node=1
while IFS= read -r line
do
  echo $line
  if [ "$i" -eq "0" ]; then
    i=$((i+1))
    continue
  fi

  first_node=$(echo $line | cut -d " " -f 1)
  last_node=$(echo $line | cut -d " " -f 2)
  os_type=$(echo $line | cut -d " " -f 3)
  node_nic=$(echo $line | cut -d " " -f 4)
  node_type=$(echo $line | cut -d " " -f 5)
  numnodes=$((numnodes + last_node - first_node + 1))

  # echo os_type=$os_type
  # echo first_node=$first_node
  # echo last_node=$last_node
  
  j=$first_node
  k=1
  while [ "$j" -le "$last_node" ]; do
    name=${node_type}${k}
    nodeadd ${name}-mgmt groups=hosts,${node_type} 
    nodeadd $name groups=ocphosts
    chtab node=${name}-mgmt hosts.ip=172.20.2.$j hosts.hostnames=$name ipmi.bmc=${name}-IMM nodepos.u=$i
    chtab node=$name hosts.ip=${BOND_NET}.$j
    j=$((j+1))
    k=$((k+1))
  done

  i=$((i+1))
done < $config_file
NODES_TO_CONFIGURE=$numnodes
chtab key=numnodes site.value=$NODES_TO_CONFIGURE

nodegrpch hosts nodehm.mgt=ipmi nodehm.cons=ipmi ipmi.password=$GENPASSWORD ipmi.username=USERID
chdef -t group hosts netboot=xnba arch=x86_64 

nodeadd gswitch1 groups=switches
nodeadd gswitch1-gswitch4 groups=switches
tabch switch=gswitch1 switches.snmpversion=3 switches.username=adminmd5 switches.password=adminmd5 switches.auth=md5 \
  switches.privacy=des switches.sshusername=admin switches.sshpassword=$GENPASSWORD
i=1
for node in `nodels switches`; do
  nodech $node hosts.ip=172.20.4.$i
  i=$((i+1))
done

umount /etc/hosts
umount /etc/resolv.conf
rm /etc/resolv.conf
chattr -i /etc/resolv.conf
echo nameserver 127.0.0.1 >> /etc/resolv.conf
chattr +i /etc/resolv.conf

rm /etc/hosts
touch /etc/hosts
echo 127.0.0.1 localhost >> /etc/hosts
makehosts ocphosts,hosts,switches
#makehosts hosts,switches,storage

i=0
first_node=1
while IFS= read -r line
do
  echo $line
  if [ "$i" -eq "0" ]; then
    i=$((i+1))
    continue
  fi

  first_node=$(echo $line | cut -d " " -f 1)
  last_node=$(echo $line | cut -d " " -f 2)
  os_type=$(echo $line | cut -d " " -f 3)
  node_nic=$(echo $line | cut -d " " -f 4)
  node_type=$(echo $line | cut -d " " -f 5)

  j=$first_node
  k=1
  while [ "$j" -le "$last_node" ]; do
    name=${node_type}${k}
    echo 172.20.3.${j} ${name}-IMM >> /etc/hosts
    j=$((j+1))
    k=$((k+1))
  done

  i=$((i+1))
done < $config_file
makedhcp -n
service dhcpd restart

#i=1
#for node in $(nodels switches); do
#        echo ${ULA}40::4:$i $node >> /etc/hosts
#        i=$((i+1))
#done
NAMESUFFIX=`gettab key=ulaprefix site.value|sed -e s/://g -e s/^fd//`
#echo ${ULA}40::1:1 lci-vcenter-$NAMESUFFIX >> /etc/hosts
#echo ${ULA}40::1:2 lci-lxca-$NAMESUFFIX >> /etc/hosts

# set up ipv6 for switches
#./utils/runswcmd.py -f "set_snmp_server" -v
#./utils/runswcmd.py -f "set_ipv6 ${ULA} 64" -v
#./utils/runswcmd.py -f "enable_ssh" -v
#./utils/runswcmd.py -f "show_ip" -v
#./setupswitch.sh
#./utils/runswcmd.py -f "set_snmp_server" -v

# auto configure all the IMMs
nodech hosts ipmi.bmcid= hypervisor.mgr= mac.mac=
service dnsmasq restart

echo -n "Setting up IMMs at "
current_timestamp
lsslp --flexdiscover # It says flex, but it supports rackmount too
while nmap -p 22 192.168.70.125|grep open; do
	lsslp --flexdiscover # It says flex, but it supports rackmount too
        echo "flexdiscover"
done
NUMNODES=`nodels hosts,-ipmi.bmcid=|wc -l`
while [ $NUMNODES -lt $NODES_TO_CONFIGURE ]; do 
	lsslp --flexdiscover # It says flex, but it supports rackmount too
	NUMNODES=`nodels hosts,-ipmi.bmcid=|wc -l`
	echo 'Waiting for all IMMs to respond'
done
echo "$NUMNODES nodes discovered by xcat"
while ! rpower hosts,-ipmi.bmcid= stat; do
	echo 'Waiting for IMM configuration to complete'
	sleep 1
done

#nimbleip=`avahi-browse _http._tcp -p -r -t |grep ^= |grep $dnic|grep Nimble|cut -d\; -f 8`
#if [ ! "$nimbleip" ]; then
#    nimbleip=`avahi-browse _ws._tcp -p -r -t |grep ^= |grep $dnic|grep Nimble|cut -d\; -f 8`
#fi

#echo "Nimble array is at $nimbleip"
while ! tmux split -h "date=$date nimbleip=$nimbleip num_nodes=$NODES_TO_CONFIGURE /lci/setupstorage.sh" ; do
	echo 'Waiting for storage setup to complete'
	sleep 1
done

NUMNODES=`nodels hosts,-ipmi.bmcid=|wc -l`
echo -n "***** $NUMNODES servers commencing next stage configuration ***** at "
current_timestamp
pasu hosts,-ipmi.bmcid= batch settings.asu
# set imm host names
for node in `nodels hosts`; do
  name=`echo $node|cut -d "-" -f 1`
  pasu $node set IMM.IMMInfo_Name "$name-IMM"
  pasu $node set IMM.HostName1 "$name-IMM"
done
nodech hosts nodehm.serialport=0 nodehm.serialspeed=115200
makeconfluentcfg hosts,-ipmi.bmcid=
nodech hosts nodehm.serialport= nodehm.serialspeed=

# for node in `nodels hosts`; do
#  addr=`rinv $node|grep "MAC Address 1"|awk '{print $5}'`
#  chtab node=$node mac.mac=$addr
# done
# makedhcp -a

i=0
first_node=1
while IFS= read -r line
do
  if [ "$i" -eq "0" ]; then
    i=$((i+1))
    continue
  fi

  first_node=$(echo $line | cut -d " " -f 1)
  last_node=$(echo $line | cut -d " " -f 2)
  os_type=$(echo $line | cut -d " " -f 3)
  node_nic=$(echo $line | cut -d " " -f 4)
  node_type=$(echo $line | cut -d " " -f 5)

  if [ "$os_type" = "rhela7" ]; then
    ostype=rhela7-x86_64-install-compute
  elif [ "$os_type" = "rhels7" ]; then
    ostype=rhels7.3-x86_64-install-compute
  else
    ostype=rhela7-x86_64-install-compute
  fi

  j=$first_node
  k=1
  while [ "$j" -le "$last_node" ]; do
    name=${node_type}${k}-mgmt
    chtab node=${name} nodepos.u=$j nodepos.rack=1 nodehm.mgt=ipmi nodehm.cons=ipmi
    addr=`rinv ${name}|grep "MAC Address ${node_nic}"|awk '{print $5}'`
    chtab node=${name} mac.mac=$addr
    makedhcp ${name}
    nodeset $name osimage=$ostype
    j=$((j+1))
    k=$((k+1))
  done

  i=$((i+1))
done < $config_file

# nodeset hosts osimage=$ostype
# nodeset hosts osimage=rhela7-x86_64-netboot-compute
rsetboot hosts,-ipmi.bmcid= net -u
rpower hosts,-ipmi.bmcid= boot
# Hosts should now come up and get their local storage set up and such automatically per directives in the chain table
# Switching attention to the storage...
# Now we need to wait for esxi to finish installing on at least one node so we have a place to put esxi
j=0
s4="96 75 66 50"
s8="96 88 83 81 80 75 66 50"
s16="96 90 90 90 90 88 85 83 80 77 70 50"
#s16="95 93 92 92 92 91 90 90 89 88 83 81 80 75 66 50"
s24="96 96 96 96 95 95 95 95 95 93 92 92 92 91 90 90 89 88 83 81 80 75 66 50"

if [ "$numnodes" -le "4" ]; then
  ratios=($s4)
elif [ "$numnodes" -le "8" ]; then
  ratios=($s8)
elif [ "$numnodes" -le "16" ]; then
  ratios=($s16)
else
  ratios=($s24)
fi

p=2
for node in `nodels hosts`; do
  if [ "$j" -lt "12" ]; then
    if ! tmux split -v -p ${ratios[j]} "/opt/confluent/bin/confetty $node"; then
      echo "Unable to show console for $node, continuing unmonitored"
    fi
  else
    tmux select-pane -t $p
    if ! tmux split -h "/opt/confluent/bin/confetty $node"; then
      echo "Unable to show console for $node, continuing unmonitored"
    fi
    p=$((p+2))
  fi
  j=$((j+1))
done

#tmux split -v "watch '/opt/xcat/bin/nodels hosts,-ipmi.bmcid= mac.mac; /opt/xcat/bin/nodeset hosts,-ipmi.bmcid= stat'"
echo -n "Waiting for Atomic/Redhat Host deployment to finish at "
current_timestamp
#sleep 840
#for node in `nodels ocphosts,-ipmi.bmcid=`; do
for node in `nodels ocphosts`; do
    echo Waiting for $node
#    while ! ping -c 1 $node > /dev/null 2>&1; do
    while ! nmap -p 22 $node|grep open; do
        # echo Checking $node every 30 seconds
        # sleep 30
        loop 10 "Checking $node "
    done
done
echo -n "... Done at "
current_timestamp

pasu hosts batch localboot.asu

log=`. showdata.sh`
echo "$log" > /lci/log/$date/showdata.log
cat /lci/log/$date/showdata.log

echo -n 'Lenovo Platform Deployer automation finished at '
current_timestamp
tmux capture-pane -S -50000 -t 0;  tmux save-buffer /lci/log/$date/lci-install-main.log; tmux delete-buffer
p=2
for node in `nodels hosts`; do
  tmux capture-pane -S -50000 -t $p;  tmux save-buffer /lci/log/$date/lci-install-${node}.log; tmux delete-buffer  
  p=$((p+1))
done 

while :; do sleep 86400; done
