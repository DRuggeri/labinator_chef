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

node.default['labinator']['network']['ipxe_endpoint'] = 'http://boss.local/chain-boot.ipxe'
node.default['labinator']['network']['log_endpoint'] = 'boss.local'
node.default['labinator']['network']['mirror_endpoint'] = 'boss.local:5000'

node.default['labinator']['network']['nodes'] = {
  'firewall' => {
    'ip' => '192.168.122.1',
    'mac' => 'b2:28:26:90:65:df',
  },
  'switch' => {
    'ip' => '192.168.122.2',
    'mac' => '00:28:72:00:07:02',
  },
  #'zeropi' => {
  #  'ip' => '192.168.122.5',
  #  'mac' => '02:00:5a:7c:69:d',
  #},
  'boss' => {
    'ip' => '192.168.122.3',
    'mac' => '16:09:01:1a:f1:a1',
    'vnc' => 5900,
  },
  'node1' => {
    'ip' => '192.168.122.11',
    'mac' => '16:09:01:1a:f4:30',
  },
  'node2' => {
    'ip' => '192.168.122.12',
    'mac' => '16:09:01:1a:f1:a3',
  },
  'node3' => {
    'ip' => '192.168.122.13',
    'mac' => '16:09:01:1a:f3:55',
  },
  'node4' => {
    'ip' => '192.168.122.14',
    'mac' => '16:09:01:1a:f1:d8',
  },
  'node5' => {
    'ip' => '192.168.122.15',
    'mac' => '16:09:01:1a:f1:92',
  },
  'node6' => {
    'ip' => '192.168.122.16',
    'mac' => '16:09:01:1a:f4:d7',
  },
}

node.default['labinator']['network']['dns_records'] = {}
node.default['labinator']['network']['dhcp_reservations'] = {}