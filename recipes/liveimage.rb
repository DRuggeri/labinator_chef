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
end

#rm -rf /var/www/html/assets/kvm-* /var/www/html/assets/kvm-live-image-amd64.iso /var/tmp/live/kvm-live-image-amd64.iso
execute 'build KVM live ISO' do
  command '/usr/local/bin/mkliveiso.sh -f /var/tmp/live/kvm-live-image-amd64.iso -a -p "openssh-server curl wget bridge-utils ethtool libvirt-daemon-system libvirt-clients virt-viewer virtinst qemu-utils qemu-system-x86 dnsmasq tcpdump htop screen" -s /var/tmp/setupkvm.sh -c /var/tmp/kvmchroot'
  creates '/var/tmp/live/kvm-live-image-amd64.iso'
  live_stream true
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
  creates '/var/www/html/assets/kvm-live-image-amd64.iso'
end

execute 'build general purpose live ISO' do
  command '/usr/local/bin/mkliveiso.sh -f /var/tmp/live/general-live-image-amd64.iso -a -p "bash bzip2 wget grep coreutils udev gnupg2 btrfs-progs gawk squashfs-tools vim curl openssl dnsutils unzip gzip rsync psmisc net-tools inetutils-telnet strace tcpdump lsof sysstat memstat file iperf iperf3 iftop ncdu socat jq yq" -c /var/tmp/generalchroot'
  creates '/var/tmp/live/general-live-image-amd64.iso'
  live_stream true
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
  creates '/var/www/html/assets/general-live-image-amd64.iso'
end

=begin
bash 'place live assets for arm64' do
  code <<-EOF
    mkdir /var/tmp/livetmp
    bsdtar -C /var/tmp/livetmp -xf /var/tmp/live/live-image-arm64.hybrid.iso
    mv /var/tmp/livetmp/live/initrd.img* /var/www/html/assets/debianlive-initrd-arm64.img
    mv /var/tmp/livetmp/live/filesystem.squashfs /var/www/html/assets/debianlive-filesystem-arm64.squashfs
    mv /var/tmp/livetmp/live/vmlinuz* /var/www/html/assets/debianlive-vmlinuz-arm64
    rm -rf /var/tmp/livetmp
    cp /var/tmp/live/live-image-arm64.hybrid.iso /var/www/html/assets/debian-live-image-arm64.hybrid.iso
  EOF
  not_if { ::File.exist?('/var/www/html/assets/debianlive-initrd-arm64.img') && !::File.exist?('/var/tmp/live/live-image-arm64.hybrid.iso') }
end
=end