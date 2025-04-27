
node.default['labinator']['talos']['scenarios'] = {
  'physical' => {
    'control-plane' => {
      'c1-physical' => node['labinator']['network']['nodes']['node1'],
      'c2-physical' => node['labinator']['network']['nodes']['node3'],
      'c3-physical' => node['labinator']['network']['nodes']['node5'],
    },
    'workers' => {
      'w1-physical' => node['labinator']['network']['nodes']['node2'],
      'w2-physical' => node['labinator']['network']['nodes']['node4'],
      'w3-physical' => node['labinator']['network']['nodes']['node6'],
    },
    'kvm' => { },
  },
}

# Generate our hybrid and virtual scenarios
['hybrid', 'virtual'].each do |type| 
  (2..4).each do |i|
    cp = {}
    kvm = {}
    num_workers = 0

    if type == 'hybrid'
      num_workers = i * 3
      cp = {
        "c1-#{type}" => node['labinator']['talos']['scenarios']['physical']['control-plane']['c1-physical'],
        "c2-#{type}" => node['labinator']['talos']['scenarios']['physical']['control-plane']['c2-physical'],
        "c3-#{type}" => node['labinator']['talos']['scenarios']['physical']['control-plane']['c3-physical'],
      }
      kvm = {
        'kvm-2' => node['labinator']['network']['nodes']['node2'],
        'kvm-4' => node['labinator']['network']['nodes']['node4'],
        'kvm-6' => node['labinator']['network']['nodes']['node6'],
      }
    else
      num_workers = i * 6
      cp = {
        "c1-#{type}" => { 'ip' => '192.168.122.21', 'mac' => 'de:ad:be:ef:20:01' },
        "c2-#{type}" => { 'ip' => '192.168.122.22', 'mac' => 'de:ad:be:ef:20:02' },
        "c3-#{type}" => { 'ip' => '192.168.122.23', 'mac' => 'de:ad:be:ef:20:03' },
      }
      kvm = {
        'kvm-1' => node['labinator']['network']['nodes']['node1'],
        'kvm-2' => node['labinator']['network']['nodes']['node2'],
        'kvm-3' => node['labinator']['network']['nodes']['node3'],
        'kvm-4' => node['labinator']['network']['nodes']['node4'],
        'kvm-5' => node['labinator']['network']['nodes']['node5'],
        'kvm-6' => node['labinator']['network']['nodes']['node6'],
      }
    end

    workers = {}
    (1..num_workers).each do |i|
      workers["w#{i}-#{type}"] = { 'ip' => "192.168.122.#{30 + i}", 'mac' => "de:ad:be:ef:30:#{sprintf('%02d', i)}" }
    end

    node.default['labinator']['talos']['scenarios']["#{type}-#{i}"] = {
      'control-plane' => cp,
      'workers' => workers,
      'kvm' => kvm,
    }
  end
end

node.default['labinator']['talos']['nodes']={}

# Render final node configs and add DNS/DHCP
node['labinator']['talos']['scenarios'].each do |type, cfg|
  node.default['labinator']['talos']['scenarios'][type]['nodes'] = {} unless node['labinator']['talos']['scenarios'][type]['nodes']

  allnodes = cfg['control-plane'].merge(cfg['workers']).merge(cfg['kvm'])
  allnodes.each do |name, info|
    n = {
      'role' => 'kvm',
      'ip' => info['ip'],
      'mac' => info['mac'],
    }
    n['role'] = 'controlplane' if name[0] == 'c'
    n['role'] = 'worker' if name[0] == 'w'

    if n['mac'].start_with?('de:ad:be:ef')
      node.default['labinator']['network']['dhcp_reservations'][n['mac']] = n['ip']
      n['installdisk'] = '/dev/vda'
    else
      n['installdisk'] = '/dev/sda'
    end

    node.default['labinator']['talos']['scenarios'][type]['nodes'][name] = n
    node.default['labinator']['network']['dns_records'][name] = n['ip']
  end
end
