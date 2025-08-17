cookbook_file '/usr/local/bin/mkliveiso.sh' do
  source 'boss/vm/mkliveiso.sh'
  mode '0755'
end

# Let boss SSH into the booted live instance
[ 'kvm', 'general' ].each do |purpose|
  directory "/var/tmp/#{purpose}chroot/root/.ssh" do
    recursive true
    action :create
  end

  bash "set up sshkey in #{purpose} chroot" do
    code <<-EOF
      cp /home/boss/.ssh/id_rsa.pub /var/tmp/#{purpose}chroot/root/.ssh/authorized_keys
      chmod 700 /var/tmp/#{purpose}chroot/root/.ssh/authorized_keys
      chmod 600 /var/tmp/#{purpose}chroot/root/.ssh/
    EOF
    creates "/var/tmp/#{purpose}chroot/root/.ssh/authorized_keys"
  end
end

# Will run in the chroot during live image build
cookbook_file '/var/tmp/setupkvm.sh' do
  source 'boss/vm/setupkvm.sh'
end

# Additional files to place into the chroot of the live images
remote_directory '/var/tmp/kvmchroot' do
  source 'boss/vm/chroot'
  mode '0755'
  files_mode '0755'
  purge false
  action :create
  notifies :run, 'execute[build KVM live ISO]', :immediately
end

#rm -rf /var/www/html/assets/kvm-* /var/www/html/assets/kvm-live-image-amd64.iso /var/tmp/live/kvm-live-image-amd64.iso
execute 'build KVM live ISO' do
  command '/usr/local/bin/mkliveiso.sh -f /var/tmp/live/kvm-live-image-amd64.iso -a -p "openssh-server curl wget bridge-utils ethtool libvirt-daemon-system libvirt-clients virt-viewer virtinst qemu-utils qemu-system-x86 dnsmasq tcpdump htop ntpsec ntpsec-ntpdate" -s /var/tmp/setupkvm.sh -c /var/tmp/kvmchroot'
  live_stream true

  action ::File.exist?('/var/tmp/live/kvm-live-image-amd64.iso') ? :nothing : :run
  notifies :run, 'bash[place live kvm assets]', :immediately
end
  
bash 'place live kvm assets' do
  code <<-EOF
    mkdir /var/tmp/livetmp
    bsdtar -C /var/tmp/livetmp -xf /var/tmp/live/kvm-live-image-amd64.iso
    mv /var/tmp/livetmp/live/initrd.img /var/www/html/assets/kvm-debianlive-initrd-amd64.img
    mv /var/tmp/livetmp/live/filesystem.squashfs /var/www/html/assets/kvm-debianlive-filesystem-amd64.squashfs
    mv /var/tmp/livetmp/live/vmlinuz /var/www/html/assets/kvm-debianlive-vmlinuz-amd64
    rm -rf /var/tmp/livetmp
    cp /var/tmp/live/kvm-live-image-amd64.iso /var/www/html/assets/kvm-live-image-amd64.iso
  EOF
  action ::File.exist?('/var/www/html/assets/kvm-live-image-amd64.iso') ? :nothing : :run
end

####
# The general purpose ISO is handy for netbooting a machine and playing around
# It is interactive and will dump the user to a root terminal on all of the TTYs
execute 'build general purpose live ISO' do
  command '/usr/local/bin/mkliveiso.sh -f /var/tmp/live/general-live-image-amd64.iso -a -p "bash bzip2 wget grep coreutils udev gnupg2 btrfs-progs gawk squashfs-tools vim curl openssl dnsutils unzip gzip rsync psmisc net-tools inetutils-telnet strace tcpdump lsof sysstat memstat file iperf iperf3 iftop ncdu socat jq yq" -c /var/tmp/generalchroot'
  live_stream true

  action ::File.exist?('/var/tmp/live/general-live-image-amd64.iso') ? :nothing : :run
  notifies :run, 'bash[place live general purpose assets]', :immediately
end

bash 'place live general purpose assets' do
  code <<-EOF
    mkdir /var/tmp/livetmp
    bsdtar -C /var/tmp/livetmp -xf /var/tmp/live/general-live-image-amd64.iso
    mv /var/tmp/livetmp/live/initrd.img /var/www/html/assets/general-debianlive-initrd-amd64.img
    mv /var/tmp/livetmp/live/filesystem.squashfs /var/www/html/assets/general-debianlive-filesystem-amd64.squashfs
    mv /var/tmp/livetmp/live/vmlinuz /var/www/html/assets/general-debianlive-vmlinuz-amd64
    rm -rf /var/tmp/livetmp
    cp /var/tmp/live/general-live-image-amd64.iso /var/www/html/assets/general-live-image-amd64.iso
  EOF
  action ::File.exist?('/var/www/html/assets/general-live-image-amd64.iso') ? :nothing : :run
end

####
# Also use our live image to wipe disks
directory '/var/www/html/nodes-ipxe/diskwipe'
node['labinator']['network']['nodes'].each do |name, n|
  next unless n['type'] == 'labnode'
  hexhyp=n['mac'].gsub(/:/, "-")

  file "/var/www/html/nodes-ipxe/diskwipe/#{hexhyp}.ipxe" do
    content <<-EOF.gsub(/^\s+/, '').gsub(/ +/, ' ')
      #!ipxe
      kernel /assets/kvm-debianlive-vmlinuz-amd64 initrd=kvm-debianlive-initrd-amd64.img \
        fetch=http://boss.local/assets/kvm-debianlive-filesystem-amd64.squashfs \
        boot=live components \
        ip=dhcp \
        consoleblank=0 \
        console=tty0 \
        kvm-amd.nested=1 \
        kvm-intel.nested=1 \

      initrd /assets/kvm-debianlive-initrd-amd64.img
      boot
    EOF
  end
end

=begin
# The below was a failed experiment, but good experience setting up TinyCore
# for netbooting. It works fine with the exception that UEFI-only firmware 
# (or maybe just the firmware on the lab boxes) fails to boot the image.
# This was at least validated to work fine in a QEMU lab
####
# We need to wipe disks if a Talos physical install was done. To do this,
# Tiny Core Linux is used with a simple modification to /etc/profile that will
# wipe /dev/sda and /dev/vda as soon as the machine boots and automatically logs
# in the tc user
checking_remote_file '/var/tmp/CorePure64-current.iso' do
  #source 'https://www.tinycorelinux.net/16.x/x86_64/release/CorePure64-current.iso'
  source 'https://distro.ibiblio.org/tinycorelinux/16.x/x86_64/release/CorePure64-16.0.iso'
  check_interval 60 * 60 * 24 * 90
  mode '0755'
  notifies :run, 'bash[place diskwipe assets]', :immediately
end

cookbook_file '/usr/local/bin/diskwipe.sh' do
  source 'boss/vm/diskwipe.sh'
end

bash 'place diskwipe assets' do
  code <<-EOF
    rm -rf /var/tmp/diskwipetmp
    mkdir /var/tmp/diskwipetmp
    bsdtar -C /var/tmp/diskwipetmp -xf /var/tmp/CorePure64-current.iso
    mkdir /var/tmp/diskwipetmp/initrd
    cd /var/tmp/diskwipetmp/initrd
    zcat ../boot/core.gz | cpio -idm
    cat /usr/local/bin/diskwipe.sh >> etc/profile
    echo ./etc/profile | cpio -H newc -o | gzip >> ../boot/core.gz

    mv /var/tmp/diskwipetmp/boot/core.gz /var/www/html/assets/tinycore-initrd
    mv /var/tmp/diskwipetmp/boot/vmlinuz /var/www/html/assets/tinycore-vmlinuz
    rm -rf /var/tmp/diskwipetmp
    cp /var/tmp/CorePure64-current.iso /var/www/html/assets/CorePure64-current.iso
  EOF
  action ::File.exist?('/var/www/html/assets/CorePure64-current.iso') ? :nothing : :run
end

directory '/var/www/html/nodes-ipxe/diskwipe'
node['labinator']['network']['nodes'].each do |name, n|
  next unless n['type'] == 'labnode'
  hexhyp=n['mac'].gsub(/:/, "-")

  file "/var/www/html/nodes-ipxe/diskwipe/#{hexhyp}.ipxe" do
    content <<-EOF.gsub(/^\s+/, '').gsub(/ +/, ' ')
      #!ipxe
      kernel /assets/tinycore-vmlinuz initrd=tinycore-initrd \
        quiet host=#{name}\

      initrd /assets/tinycore-initrd
      boot
    EOF
  end
end
=end