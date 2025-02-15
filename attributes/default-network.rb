#NOTE: vnc, cpus, mem, disk are only used when creating VMs
node.default['labinator']['network']['gateway'] = '192.168.122.1'
node.default['labinator']['network']['netmask'] = '255.255.255.0'
node.default['labinator']['network']['cidr'] = '/24'
node.default['labinator']['network']['subnet'] = '192.168.122.0/24'
node.default['labinator']['network']['dns'] = '192.168.122.3'
node.default['labinator']['network']['ntp'] = '192.168.122.3'

node.default['labinator']['network']['dns_upstream'] = '192.168.0.1'
node.default['labinator']['network']['dns_domain'] = 'local'
node.default['labinator']['network']['dhcp_start'] = '192.168.122.200'
node.default['labinator']['network']['dhcp_end'] = '192.168.122.254'

node.default['labinator']['network']['ipxe_endpoint'] = 'http://boss.local/talos-boot.ipxe'
node.default['labinator']['network']['log_endpoint'] = 'boss.local'
node.default['labinator']['network']['mirror_endpoint'] = 'boss.local:5000'

# See dnsmasq.rb recipe - will create name.domain records (example: boss.local)
node.default['labinator']['network']['dns_records'] = {
  # Physical nodes - supporting systems
  'firewall' => '192.168.122.1',
  'switch' => '192.168.122.2',
  'boss' => '192.168.122.3',

  # Physical nodes - lab victims
  'node1' => '192.168.122.10',
  'node2' => '192.168.122.11',
  'node3' => '192.168.122.12',
  'node4' => '192.168.122.13',
  'node5' => '192.168.122.14',
  'node6' => '192.168.122.15',

  # Kubernetes nodes - control plane
  'c1' => '192.168.122.20',
  'c2' => '192.168.122.21',
  'c3' => '192.168.122.22',
  'koobs' => [ '192.168.122.20', '192.168.122.21', '192.168.122.22' ],
}

# pre-generate DNS records for up to 32 worker nodes from 192.168.122.30 onwarward
for i in 0..32
  node.default['labinator']['network']['dns_records'][i+1] = "192.168.122.#{30 + i}"
end

# manual DHCP reservations for playing around
node.default['labinator']['network']['dhcp_reservations'] = {
  '02:00:5a:7c:69:dc' => '192.168.122.5', # Zeropi 3
  'b2:28:26:90:65:df' => '192.168.122.199', # Nanopi R3s
}