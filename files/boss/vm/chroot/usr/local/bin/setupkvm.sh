#!/bin/sh

# Set up a bridge with the real MAC address as the bridge address and a generated mac on the physical interface
test -d /tmp/netbridge || mkdir /tmp/netbridge
cp /etc/network/interfaces /tmp/netbridge/interfaces
ip a > /tmp/netbridge/ipa
cat /sys/class/net/enp1s0/address > /tmp/netbridge/enp1s0address

MAC=`ethtool -P enp1s0 | cut -d : -f 2-`

# For some reason, the first restart still has the auto addresses on the enp1s0 interface
# This happens even with ip addr del, ip link set .. down, ifdown, etc before restarting
# So... keep restarting networking until there are no interfaces found!
COUNT=0
while [ `ip addr show enp1s0 | awk '/inet/ {print $2}' | wc -l` -gt 0 ];do
  echo "
auto lo
iface lo inet loopback

auto enp1s0
iface enp1s0 inet manual
  hwaddress random

auto br0
iface br0 inet dhcp
  hwaddress ether $MAC
  bridge_ports enp1s0
" > /etc/network/interfaces
  systemctl restart networking
  ((COUNT++))
  echo "Restarted networking - $COUNT" >> /tmp/netbridge/startlog
done

# Take over the disk with a new GPT partition spanning the whole drive for VM images
for DEV in /dev/vda /dev/sda;do
    if [ -b $DEV ];then
        sfdisk $DEV -W always -w always << EOF
label: gpt
start=, size= 100M, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name="EFI system partition"
type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="images"
EOF
        mkfs.ext4 -F "${DEV}2"
        mount "${DEV}2" /var/lib/libvirt/images
        break
    fi
done

curl -k -o /var/lib/libvirt/images/metal-amd64.iso https://boss.local/assets/metal-amd64.iso