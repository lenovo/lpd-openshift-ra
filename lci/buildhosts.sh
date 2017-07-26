ULA=${ula}
umount /etc/hosts
umount /etc/resolv.conf
rm /etc/resolv.conf
chattr -i /etc/resolv.conf
echo nameserver 127.0.0.1 >> /etc/resolv.conf
chattr +i /etc/resolv.conf

rm /etc/hosts
touch /etc/hosts
echo 127.0.0.1 localhost >> /etc/hosts
makehosts hosts,switches,storage
i=1
for node in $(nodels hosts); do
	echo ${ULA}40::$i:0 $node >> /etc/hosts
	i=$((i+1))
done
NAMESUFFIX=`gettab key=ulaprefix site.value|sed -e s/://g -e s/^fd//`
echo ${ULA}40::9:0 lci-vcenter-$NAMESUFFIX >> /etc/hosts
