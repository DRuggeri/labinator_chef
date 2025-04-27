#!/bin/sh

set -e

test -f /etc/systemd/system/multi-user.target.wants/libvirtd.service || ln -s /lib/systemd/system/libvirtd.service /etc/systemd/system/multi-user.target.wants/libvirtd.service
test -f /etc/systemd/system/multi-user.target.wants/setupkvm.service || ln -s /lib/systemd/system/setupkvm.service /etc/systemd/system/multi-user.target.wants/setupkvm.service

test -f /etc/libvirt/qemu/networks/default.xml && cat /etc/libvirt/qemu/networks/default.xml
echo '
<network>
    <name>default</name>
    <forward mode="bridge" />
    <bridge name="br0" />
</network>
' > /etc/libvirt/qemu/networks/default.xml

test -d /etc/libvirt/qemu/networks/autostart || mkdir /etc/libvirt/qemu/networks/autostart
test -f /etc/libvirt/qemu/networks/autostart/default.xml || ln -s /etc/libvirt/qemu/networks/default.xml /etc/libvirt/qemu/networks/autostart/default.xml

echo 'security_driver = "none"' > /etc/libvirt/qemu.conf
