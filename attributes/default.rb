node.default['labinator']['network']['talos_netdev'] = 'enp1s0'

node.default['labinator']['versions'] = {
  'prometheus' => '3.0.1',
  'loki' => '3.3.0',
  'talos' => '1.9.1',
  'matchbox' => '0.11.0',
  'helm' => '3.16.3',
  'otelcol' => '0.115.1',
  'otelcolchart' => '0.115.1',
  'kyverno' => '1.13.2',
  'kyvernochart' => '3.3.4',

  # Site tools
  'protoc' => '29.3',
  'go' => '1.23.5',
}

node.default['labinator']['nodes'] = {
#  'swtich' => {
#    'ip' => '192.168.122.2',
#    'mac' => '00:28:72:00:07:02',
#  },
#  'boss' => {
#    'ip' => '192.168.122.3',
#    'mac' => '16:09:01:1a:f1:a1',
#    'installdisk' => '/dev/sda',
#    'vnc' => 5900,
#  },
  'c1' => {
    'role' => 'controlplane',
    'ip' => '192.168.122.20',
    'mac' => 'de:ad:be:ef:00:20',
    'installdisk' => '/dev/vda',
    'vnc' => 5910,
  },
  'c2' => {
    'role' => 'controlplane',
    'ip' => '192.168.122.21',
    'mac' => 'de:ad:be:ef:00:21',
    'installdisk' => '/dev/vda',
    'vnc' => 5911,
  },
  'c3' => {
    'role' => 'controlplane',
    'ip' => '192.168.122.22',
    'mac' => 'de:ad:be:ef:00:22',
    'installdisk' => '/dev/vda',
    'vnc' => 5912,
  },
  'w1' => {
    'role' => 'worker',
    'ip' => '192.168.122.30',
    'mac' => 'de:ad:be:ef:00:30',
    'installdisk' => '/dev/vda',
    'vnc' => 5915,
  },
  'w2' => {
    'role' => 'worker',
    'ip' => '192.168.122.31',
    'mac' => 'de:ad:be:ef:00:31',
    'installdisk' => '/dev/vda',
    'vnc' => 5916,
  },
  'w3' => {
    'role' => 'worker',
    'ip' => '192.168.122.32',
    'mac' => 'de:ad:be:ef:00:32',
    'installdisk' => '/dev/vda',
    'vnc' => 5917,
  },
}

# Apply some defaults for all node VMs
node['labinator']['nodes'].each do |nodename, n|
  if nodename.start_with?('c')
    node.default['labinator']['nodes'][nodename]['cpus'] = 2
    node.default['labinator']['nodes'][nodename]['mem'] = 2048
    node.default['labinator']['nodes'][nodename]['disk'] = 10
  else
    node.default['labinator']['nodes'][nodename]['cpus'] = 1
    node.default['labinator']['nodes'][nodename]['mem'] = 1536
    node.default['labinator']['nodes'][nodename]['disk'] = 10
  end
end