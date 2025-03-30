
group 'boss'
user 'boss' do
  uid 1000
  group 'boss'
  home '/home/boss'
end

directory '/home/boss' do
  owner 'boss'
  group 'boss'
end

directory '/root/.ssh' do
  mode '0700'
end

file '/root/.ssh/authorized_keys' do
  content 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDgX3hnqTTMMYjbwmHy9QqvnG9HNDTSDiHS6bU6Z2QImoRZWd5B0nc8HfSvEj1qhLKVyV45ARKXFDbh8D5dcMe9G9ZysEFdTeKZI8ovjfwAtlz4THbaDArz9woLDsZx1dcSVLnhXXo/bT8GqrNPxki3Zgf/LNYmqTKcaWlZIXME4B4J2Y3KwvqZo8T+Q6V33Y/jH/TzZucFguVsG3SGg0QXhXfi1757GXpYVYSxrVsURJ6QXaa2i4e2zkjV7+J7xufdF6og265wLDAJgXyldPRo377O3cMwo0I3QuAtzw21GpcAGn2BdEULZdBGiSuG9FsykBzGB6CG+QkYKBfkaD67 Danimal@Danimal-PC
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDpOgnZn/MrCAVzxkTGiyq2NXtIKJSbiufS/YKOYxfFQZe1E+2Naz841QIQvYujDSTIGvu7n1uRVUgmeN9bStSorX4eqDE+31awVGlNPKY1D4A//KSdKgN2HCDo5pU7E14x5c1qohPbxdAD6zwzUz9ciM+pQCNc6jC/VPUN6Hz54EYuuk5dUR0gQIaPOh0uhBdUvjvqCcz0s4mcxSWJviO/RpjVPRsVNImGAJS1FT13ALo6KiKYPZbV2I0PIJx6VunwYZMFf1B73D9qIwRTzo0S42VVSlRP+ulUO3AFOmlLEjDseY7YsrsW0RGRIFMSORKUGPQW4rt7t8BPGNEYls6JiVHWluiE8Jbbw5bzbd8Xzjk3bttJ7QDrJ8DAmiCb96S59422/qNNC8MIjufXl/xAHQiwyidyQtgrmoD56G4pMEUKk+GJNbzq0C1654DoebmIYkMivcGb1xAUpwbPd8VI57k1fiJOY7cuy6qHYkL4Cvndqb2UC6wJEPEr7kZt5KaZxwB9+Bz5p/rb2QWn0eih3gZb5GuinMYsIzo+Gftbxe90vZaN3BaUbcpNkWGMlRmNpFjfFkV8/JJGw1Am+5HzwjhX8lT0We7uUFxHkoEqfnFXU7+WSRbk5fR6NdNfLZI24YA5OEX5djLnR1GkSShmE0JGpvoRjKHoJrigAw3OMw== root@koob'
  mode '0700'
end

service 'chef-client' do
  action [:disable, :stop]
end
file '/etc/init.d/chef-client' do
  action :delete
end

[
  'brltty'
].each do |pkg|
  package pkg do
    action :remove
  end
end

[
  'wget',              #Web client
  'curl',              #Web client
  'git',               #Duh...
  'vim',               #Better editor
  'openssl',           #SSL, of course
  'ssl-cert',          #Adds standard ssl-cert group for automated certs
  'dnsutils',          #BIND clients
  'unzip',             #Compression
  'gzip',              #Compression
  'rsync',             #Remote file sync
  'psmisc',            #fuser, killall
  'net-tools',         #netstat, ifconfig, iwconfig, route, iptunnel, arp
  'inetutils-telnet',  #netstat, ifconfig, iwconfig, route, iptunnel, arp
  'strace',            #Troubleshooting
  'tcpdump',           #Troubleshooting
  'telnet',            #Troubleshooting
  'lsof',              #Troubleshooting
  'sysstat',           #Troubleshooting
  'memstat',           #Troubleshooting
  'file',              #Troubleshooting
  'iperf',             #Network throughput testing
  'iperf3',            #Network throughput testing
  'iftop',             #Network throughput monitoring
  'iotop',             #Network throughput monitoring
  'fio',               #Disk throughput testing
  'jq',                #Sed... for JSON
  'yq',                #Sed... for YAML, XML, and ALSO JSON
  'ncdu',              #Disk space analyzer
  'socat',             #Telnet for local sockets
  'dnsmasq',           #DNS, DHCP, and TFTP server
  'ipxe',              #Netboot assets (ipxe.efi and undionly.kpxe)
  'screen',            #Serial read/write

  #ISO tools
  'genisoimage',
  'syslinux-utils',
  'libarchive-tools',
  'squashfs-tools',
  'cpio',
  'btrfs-progs', #flatcar-installer
  'gawk',        #flatcar-installer
].each do |name|
  package name do
    action :install
  end
end

[
  'charts',
  'talos',
].each do |dir|
  directory "/home/boss/#{dir}" do
    owner 'boss'
    group 'boss'
  end
end

group 'monitors' do
  gid 1001
end

user 'monitors' do
  uid 1001
  gid 'monitors'
  shell '/usr/sbin/nologin'
end

file '/etc/network/interfaces' do
  content '
auto lo
iface lo inet loopback

auto enp1s0
allow-hotplug enp1s0
iface enp1s0 inet static
  address 192.168.122.3/24
  gateway 192.168.122.1
'
end

# Create TFTP and HTTP root in advance because dnsmasq needs the folder as does apache
directory '/var/www/html' do
  recursive true
end

##### NTP client and server
include_recipe 'labinator::ntp'

##### Step CA
include_recipe 'labinator::step-ca'

##### DNS, TFTP, DHCP, etc
include_recipe 'labinator::dnsmasq'

##### Apache httpd
include_recipe 'labinator::apache'

##### Docker
include_recipe 'labinator::docker'

### Prometheus
include_recipe 'labinator::prometheus'

### OpenTelemetry collector (for syslog and tcplog)
include_recipe 'labinator::otelcol'

##### Blackbox exporter
include_recipe 'labinator::blackbox-exporter'

### Loki
include_recipe 'labinator::loki'

### Grafana
include_recipe 'labinator::grafana'

#### Container registry
include_recipe 'labinator::registry'

##### Binaries
checking_remote_file '/usr/bin/kubectl' do
  source 'https://dl.k8s.io/v1.31.4/bin/linux/amd64/kubectl'
  check_interval 60 * 60 * 24 * 90
  mode '0755'
end

checking_remote_file '/usr/bin/talosctl' do
  source "https://github.com/siderolabs/talos/releases/download/v#{node['labinator']['versions']['talos']}/talosctl-linux-amd64"
  check_interval 60 * 60 * 24 * 90
  mode '0755'
end

remote_archive "https://github.com/poseidon/matchbox/releases/download/v#{node['labinator']['versions']['matchbox']}/matchbox-v#{node['labinator']['versions']['matchbox']}-linux-amd64.tar.gz" do
  directory '/usr/bin'
  check_interval 60 * 60 * 24 * 90
  strip_components 1
  files '*/matchbox'
end

remote_archive "https://get.helm.sh/helm-v#{node['labinator']['versions']['helm']}-linux-amd64.tar.gz" do
  directory '/usr/bin'
  check_interval 60 * 60 * 24 * 90
  strip_components 1
  files '*/helm'
end

remote_archive "https://go.dev/dl/go#{node['labinator']['versions']['go']}.linux-amd64.tar.gz" do
  directory '/usr/local'
  check_interval 60 * 60 * 24 * 90
end
link '/usr/bin/go' do
  to '/usr/local/go/bin/go'
  link_type :symbolic
end

##### Container image mirroring
include_recipe 'labinator::container-images'

##### Matchbox
# Moved to apache and dnsmasq only
#include_recipe 'labinator::matchbox'

# Set a default netboot configuration for unknown x86 devices (ipxe)
directory '/var/www/html/ipxe' do
  recursive true
end
file '/var/www/html/ipxe/default.ipxe' do
  content <<-EOF.gsub(/^    /, '')
    #!ipxe
    kernel /assets/debianlive-vmlinuz-amd64 initrd=debianlive-initrd-amd64.img boot=live components console=ttyS0 fetch=boss.local/assets/debianlive-filesystem-amd64.squashfs
    initrd /assets/debianlive-initrd-amd64.img
    boot
  EOF
end


# Set a default netboot config for unknown ARM devices (PXE)
directory '/var/www/html/pxelinux.cfg' do
  recursive true
end
file '/var/www/html/pxelinux.cfg/default-arm' do
  content <<-EOF.gsub(/^    /, '') 
    LABEL linux
      KERNEL /assets/debianlive-vmlinuz-arm64
      APPEND initrd=/assets/debianlive-initrd-arm64.img boot=live components fetch=boss.local/assets/debianlive-filesystem-arm64.squashfs splash=verbose console=ttyS0,115200 consoleblank=0 usb-storage.quirks=0x2537:0x1066:u,0x2537:0x1068:u cgroup_enable=memory
  EOF
end


include_recipe 'labinator::talos-netboot'

##### Optional - livecd image creation
include_recipe 'labinator::liveimage'

##### Set up our desktop
include_recipe 'labinator::desktop'

##### Finally - load up labwatch
include_recipe 'labinator::labwatch'