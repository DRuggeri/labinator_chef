# SEE https://ipxe.org/download
[
  'make',
  'gcc',
  'build-essential',
  'binutils',
  'mtools',
  'liblzma5',
  'liblzma-dev',
].each do |name|
  package name do
    action :install
  end
end

# Use "dumb" bash command since git resource will detect changes to files in repo
bash 'setup IPXE source' do
  code <<-EOF.gsub(/^    /, '')
    cd /usr/local/src
    rm -rf ipxe

    # Known good commit as of 2025-09-18 after fixes to v1.21.1 tag were made
    git clone --branch master https://github.com/ipxe/ipxe.git
    git checkout 6464f2edb855274cd3e311eff0aa718935b3eef6
    cd ipxe/src

    # Patch Makefile to avoid PIE issues on gcc6+ and later
    perl -pi -e 's/^(CFLAGS.*:=)$/$1 -fno-pie/g;s/^(LDFLAGS.*:=)$/$1 -no-pie/g' Makefile

    echo "
    #undef CONSOLE_PCBIOS
    #define CONSOLE_PCBIOS CONSOLE_USAGE_ALL
    #define CONSOLE_SYSLOG CONSOLE_USAGE_ALL
    #undef LOG_LEVEL
    #define LOG_LEVEL LOG_ALL
    " > config/local/console.h

    echo "
    #ifndef IMAGE_PNG
    #define IMAGE_PNG
    #endif
    #define CONSOLE_CMD
    " > config/local/console.h
  EOF
  live_stream true
  not_if { ::File.exist?('/usr/local/src/ipxe/src/bin-x86_64-efi/ipxe.efi') && ::File.exist?('/usr/local/src/ipxe/src/bin-x86_64-pcbios/undionly.kpxe') }
end

execute 'build ipxe' do
  command 'make NO_WERROR=1 bin-x86_64-efi/ipxe.efi && make NO_WERROR=1 bin-x86_64-pcbios/undionly.kpxe && cp bin-x86_64-efi/ipxe.efi /var/www/html/ipxe.efi && cp bin-x86_64-pcbios/undionly.kpxe /var/www/html/undionly.kpxe'
  cwd '/usr/local/src/ipxe/src'
  live_stream true
  not_if { ::File.exist?('/usr/local/src/ipxe/src/bin-x86_64-efi/ipxe.efi') && ::File.exist?('/usr/local/src/ipxe/src/bin-x86_64-pcbios/undionly.kpxe') }
  action :run
end

file '/var/www/html/chain-boot.ipxe' do
  content <<-EOF.gsub(/^\s+/, '')
    #!ipxe
    console --x 800 --y 600
    console --picture http://boss.local/assets/bootimg.png

    set syslog #{node['labinator']['network']['syslog']}
    sync

    # If at first you don't succeed, try, try, try again
    chain nodes-ipxe/lab/${mac:hexhyp}.ipxe
    chain nodes-ipxe/lab/${mac:hexhyp}.ipxe
    chain nodes-ipxe/lab/${mac:hexhyp}.ipxe
  EOF
end

cookbook_file '/var/www/html/assets/bootimg.png' do
  source 'bootimg/logo-white.png'
  mode '0755'
  action :create
end
