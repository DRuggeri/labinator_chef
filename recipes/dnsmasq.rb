package 'ipxe'

# Excellent references:
# https://github.com/boliu83/ipxe-boot-server
# https://openwrt.org/docs/guide-user/base-system/dhcp_configuration#multi-arch_tftp_boot

dns_records = [ '      \\' ]
dhcp_hosts  = [ '      \\' ]

# Populate all of the nodes in the network with DNS and DHCP
node['labinator']['network']['nodes'].each do |name, info|
  dns_records << "      --host-record=#{name}.local,#{info['ip']} \\"
  dhcp_hosts  << "      --dhcp-host=#{info['mac']},#{info['ip']} \\"
end

# Add additional DNS and DHCP entries
node['labinator']['network']['dns_records'].each do |name, val|
  # Always coax to array to support DNS names with round-robin values
  vals = val.is_a?(String) ? [ val ] : val
  vals.each do |addr|
    dns_records << "      --host-record=#{name}.local,#{addr} \\"
  end
end

node['labinator']['network']['dhcp_reservations'].each do |mac, ip|
  dhcp_hosts << "      --dhcp-host=#{mac},#{ip} \\"
end

directory '/var/lib/www/html' do
  recursive true
end

execute 'place pxe files' do
  command 'cp /usr/lib/ipxe/ipxe.efi /usr/lib/ipxe/undionly.kpxe /var/www/html/'
  not_if { ::File.exist?('/var/www/html/ipxe.efi') && ::File.exist?('/var/www/html/undionly.kpxe') }
end

systemd_unit 'dnsmasq.service' do
  content <<-EOU.gsub(/^    /, '')
    [Unit]
    After=network.target

    [Service]
    ExecStart=/usr/sbin/dnsmasq \\
      --no-daemon \\
      --no-resolv \\
      --server=#{node['labinator']['network']['dns_upstream']} \\
      --enable-tftp --tftp-root=/var/www/html \\
#{dns_records.join("\n")}
#{dhcp_hosts.join("\n")}
      \\
      --dhcp-range=#{node['labinator']['network']['dhcp_start']},#{node['labinator']['network']['dhcp_end']},24h \\
      --dhcp-option=1,#{node['labinator']['network']['netmask']} \\
      --dhcp-option=3,#{node['labinator']['network']['gateway']} \\
      --dhcp-option=6,#{node['labinator']['network']['dns']} \\
      --dhcp-option=7,#{node['labinator']['network']['syslog']} \\
      --dhcp-option=15,#{node['labinator']['network']['dns_domain']} \\
      --dhcp-option=42,#{node['labinator']['network']['ntp']} \\
      --dhcp-option=119,#{node['labinator']['network']['dns_domain']} \\
      --dhcp-match=set:bios,option:client-arch,0 \\
      --dhcp-boot=tag:bios,undionly.kpxe \\
      --dhcp-match=set:efi32,option:client-arch,6 \\
      --dhcp-boot=tag:efi32,ipxe.efi \\
      --dhcp-match=set:efibc,option:client-arch,7 \\
      --dhcp-boot=tag:efibc,ipxe.efi \\
      --dhcp-match=set:efi64,option:client-arch,9 \\
      --dhcp-boot=tag:efi64,ipxe.efi \\
      --dhcp-userclass=set:ipxe,iPXE \\
      --dhcp-boot=tag:ipxe,#{node['labinator']['network']['ipxe_endpoint']} \\
      --log-queries \\
      --log-dhcp
    Restart=on-failure

    [Install]
    WantedBy=default.target
  EOU

  triggers_reload true
  action [:create, :enable]
  notifies :restart, "service[dnsmasq]", :immediately
  notifies :run, "execute[await dns]", :immediately
end

service 'dnsmasq' do
  action [:enable, :start]
end

execute 'await dns' do
  command "while [ -z `dig +short boss.local @127.0.0.1` ];do sleep 1;done"
  action :nothing
end

# dnsmasq is up - start using it immediately
file '/etc/resolv.conf' do
  content <<-EOF.gsub(/^    /, '')
    search #{node['labinator']['network']['dns_domain']}
    domain #{node['labinator']['network']['dns_domain']}
    nameserver #{node['labinator']['network']['dns']}
  EOF
end
