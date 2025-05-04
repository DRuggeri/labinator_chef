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
  # Fleshed out below
  'hybrid-2' => {},
  'hybrid-3' => {},
  'hybrid-4' => {},
  'virtual-2' => {},
  'virtual-3' => {},
  'virtual-4' => {},
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

require 'json'
scenario_config = {}

# Render final node configs, add DNS/DHCP records, and build a configuration file for labwatch
node['labinator']['talos']['scenarios'].each do |type, cfg|
  scenario_config[type] = { 'nodes' => {} }
  node.default['labinator']['talos']['scenarios'][type]['nodes'] = {} unless node['labinator']['talos']['scenarios'][type]['nodes']
  node.default['labinator']['talos']['scenarios'][type]['vms'] = {}

  # Used to render the physical -> virtual mappings
  hypervisors = []

  if type.start_with?('hybrid')
    hypervisors = [
      node['labinator']['network']['nodes']['node2'],
      node['labinator']['network']['nodes']['node4'],
      node['labinator']['network']['nodes']['node6'],
    ] 
  elsif type.start_with?('virtual')
    hypervisors = [
      node['labinator']['network']['nodes']['node1'],
      node['labinator']['network']['nodes']['node2'],
      node['labinator']['network']['nodes']['node3'],
      node['labinator']['network']['nodes']['node4'],
      node['labinator']['network']['nodes']['node5'],
      node['labinator']['network']['nodes']['node6'],
    ]
  end
  hindex=0

  allnodes = cfg['control-plane'].merge(cfg['workers']).merge(cfg['kvm'])
  allnodes.each do |name, info|
    n = {
      'ip' => info['ip'],
      'mac' => info['mac'],
      'name' => name,
    }

    case name[0]
    when 'c'
      n['role'] = 'controlplane'
    when 'w'
      n['role'] = 'worker'
    when 'k'
      n['role'] = 'kvm'
    else
      raise "A node named #{name} starts with something other than c, w, or k - I don't know how to handle that!"
    end

    if n['mac'].start_with?('de:ad:be:ef')
      node.default['labinator']['network']['dhcp_reservations'][n['mac']] = n['ip']
      n['type'] = 'virtual'
      n['installdisk'] = '/dev/vda'

      # Set the physical node this will live on
      n['hypervisor'] = hypervisors[hindex]
      hindex += 1
      hindex = 0 if hindex >= hypervisors.length()
    else
      if n['role'] == 'kvm'
        n['type'] = 'hypervisor'
      else
        n['type'] = 'physical'
        n['installdisk'] = '/dev/sda'
      end
    end

    # Ugly hack, but this keeps the config "clean" since ruby hashes are references and once
    # assigned to a Chef node attribute, many Chef-y things get added to it, junking up
    # the serialized object
    scenario_config[type]['nodes'][name] = JSON.parse(JSON.generate(n))
    
    node.default['labinator']['talos']['scenarios'][type]['nodes'][name] = n
    node.default['labinator']['network']['dns_records'][name] = n['ip']
  end

  # Also add each control plane node and worker node to DNS names for the cluster
  node.default['labinator']['network']['dns_records'][type] = []
  node.default['labinator']['network']['dns_records']["#{type}-workers"] = []

  cfg['control-plane'].each do |name, n|
    node.default['labinator']['network']['dns_records'][type] << n['ip']
  end
  cfg['workers'].each do |name, n|
    node.default['labinator']['network']['dns_records']["#{type}-workers"] << n['ip']
  end
end

require 'yaml'
node.default['labinator']['talos']['scenario_config'] = YAML.dump(scenario_config)