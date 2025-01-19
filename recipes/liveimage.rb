file '/usr/local/bin/mkemptylivecd.sh' do
  content <<-EOF
  #!/usr/bin/bash
  # https://live-team.pages.debian.net/live-manual/html/live-manual/index.en.html
  
  test -d /var/tmp/live || mkdir /var/tmp/live
  cd /var/tmp/live
  
  curl --connect-timeout 5 -k https://romulus.home.bitnebula.com/live-image-arm64.hybrid.iso -o live-image-arm64.hybrid.iso
  if curl --connect-timeout 5 -k https://romulus.home.bitnebula.com/live-image-amd64.hybrid.iso -o live-image-amd64.hybrid.iso;then
    exit
  fi
  
  if [ ! -f /usr/bin/lb ];then
    apt-get remove -y live-build
    apt-get install -y po4a gettext debhelper-compat arch-test debootstrap
    cd
    test -d live-build || git clone https://salsa.debian.org/live-team/live-build.git
    cd live-build
    dpkg-buildpackage -b -uc -us
    cd ../
    dpkg -i live-build_*_all.deb
    apt-get remove -y po4a gettext debhelper-compat
    apt autoremove -y
  fi
  
  rm -rf temporary-working
  mkdir temporary-working
  cd temporary-working
  
  lb config --apt-indices false --apt-recommends false --distribution stable
  
  echo "bash
  bzip2
  wget
  grep
  coreutils
  udev
  gnupg2
  btrfs-progs
  gawk
  squashfs-tools
  vim
  curl
  openssl
  dnsutils
  unzip
  gzip
  rsync
  psmisc
  net-tools
  inetutils-telnet
  strace
  tcpdump
  lsof
  sysstat
  memstat
  file
  iperf
  iperf3
  iftop
  ncdu
  socat
  jq
  yq
  " >> ./config/package-lists/live.list.chroot
  
  perl -pi -e 's/ quiet splash//g' config/binary
  perl -pi -e 's/components/components console=ttyS0/g' config/binary
  
  cp -r /usr/share/live/build/bootloaders/isolinux config/bootloaders/
  perl -pi -e 's/timeout [0-9]+/timeout 1/g' config/bootloaders/isolinux/isolinux.cfg
  
  for override in "serial-getty@" "getty@";do
    mkdir -p config/includes.chroot/etc/systemd/system/${override}.service.d/
    echo "[Service]
  ExecStart=
  ExecStart=-/sbin/agetty --autologin root --noclear %I 38400 linux
  Type=idle
  " > config/includes.chroot/etc/systemd/system/${override}.service.d/override.conf
  done
  
  mkdir config/includes.chroot/root/
  echo '#!/usr/bin/bash
  if [[ -f /autorun.sh ]];then
    exec bash /autorun.sh
  fi
  ' > config/includes.chroot/root/.profile
  
  time lb build
  mv live-image-amd64.hybrid.iso ../
  cd temporary-working/chroot
  find . | cpio -H newc -o | gzip > /var/www/html/assets/debianlive-fullrd.img.gz
  EOF
  mode '0755'
 end

execute 'build live ISO' do
  command '/usr/local/bin/mkemptylivecd.sh'
  creates '/var/tmp/live/live-image-amd64.hybrid.iso'
end
  
bash 'place live assets for amd64' do
  code <<-EOF
    mkdir /var/tmp/livetmp
    bsdtar -C /var/tmp/livetmp -xf /var/tmp/live/live-image-amd64.hybrid.iso
    mv /var/tmp/livetmp/live/initrd.img /var/www/html/assets/debianlive-initrd-amd64.img
    mv /var/tmp/livetmp/live/filesystem.squashfs /var/www/html/assets/debianlive-filesystem-amd64.squashfs
    mv /var/tmp/livetmp/live/vmlinuz /var/www/html/assets/debianlive-vmlinuz-amd64
    rm -rf /var/tmp/livetmp
    cp /var/tmp/live/live-image-amd64.hybrid.iso /var/www/html/assets/debian-live-image-amd64.hybrid.iso
  EOF
  not_if { ::File.exist?('/var/www/html/assets/debianlive-initrd-amd64.img') }
end

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