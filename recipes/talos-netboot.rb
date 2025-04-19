file '/var/www/html/chain-boot.ipxe' do
  content "#!ipxe
chain nodes-ipxe/lab/${mac:hexhyp}.ipxe
"
end

directory '/var/www/html/nodes-ipxe' do
  owner 'boss'
  group 'boss'
end

directory '/var/www/html/pxelinux.cfg'

##### iPXE assets
checking_remote_file '/var/www/html/assets/talos-initramfs-amd64.xz' do
  source "https://github.com/siderolabs/talos/releases/download/v#{node['labinator']['versions']['talos']}/initramfs-amd64.xz" 
  check_interval 60 * 60 * 24 * 90
  mode '0755'
end

checking_remote_file '/var/www/html/assets/talos-vmlinuz-amd64.xz' do
  source "https://github.com/siderolabs/talos/releases/download/v#{node['labinator']['versions']['talos']}/vmlinuz-amd64"
  check_interval 60 * 60 * 24 * 90
  mode '0755'
end

directory '/home/boss/talos' do
  owner 'boss'
  group 'boss'
end

directory '/home/boss/talos/scenarios'

node['labinator']['talos']['scenarios'].each do |scenario, scenario_config|
  directory "/var/www/html/nodes-ipxe/#{scenario}"
  directory "/home/boss/talos/scenarios/#{scenario}"

  template "/home/boss/talos/scenarios/#{scenario}/patch-all.yaml" do
    source 'talos-netboot/patch-all.yaml.erb'
    variables(
      network: node['labinator']['network'],
      nodes: scenario_config['nodes'],
    )
    notifies :run, "execute[generate #{scenario} talos configs]"
  end
  
  execute "create #{scenario} talos secrets" do
    creates "/home/boss/talos/scenarios/#{scenario}/secrets.yaml"
    command "talosctl gen secrets -o /home/boss/talos/scenarios/#{scenario}/secrets.yaml"
    notifies :run, "execute[generate #{scenario} talos configs]"
  end

  execute "generate #{scenario} talos configs" do
    creates "/home/boss/talos/scenarios/#{scenario}/controlplane.yaml"
    command "talosctl gen config #{scenario} https://#{scenario}.local:6443 \
      --force \
      --with-secrets /home/boss/talos/scenarios/#{scenario}/secrets.yaml \
      --config-patch @/home/boss/talos/scenarios/#{scenario}/patch-all.yaml \
      --output /home/boss/talos/scenarios/#{scenario} \
    "
  end

  # Generate per-node configs
  controlplane_ips = []
  all_ips = []
  scenario_config['nodes'].each do |nodename, n|
    controlplane_ips << n['ip'] if n['role'] == 'controlplane'
    all_ips << n['ip']
    hexhyp=n['mac'].gsub(/:/, "-")

    template "/home/boss/talos/scenarios/#{scenario}/patch-node-#{nodename}.yaml" do
      source 'talos-netboot/patch-node.yaml.erb'
      variables(
        nodename: nodename,
        n: n,
        network: node['labinator']['network'],
      )
    end

    execute "create final #{scenario} node config for #{nodename}" do
      command "talosctl \
        --talosconfig /home/boss/talos/scenarios/#{scenario}/talosconfig \
        machineconfig patch /home/boss/talos/scenarios/#{scenario}/#{n['role']}.yaml \
        --patch @/home/boss/talos/scenarios/#{scenario}/patch-node-#{nodename}.yaml \
        -o /home/boss/talos/scenarios/#{scenario}/node-#{nodename}.yaml \
      "
      creates "/home/boss/talos/scenarios/#{scenario}/node-#{nodename}.yaml"
      subscribes :run, "template[/home/boss/talos/scenarios/#{scenario}/patch-all.yaml]"
      subscribes :run, "execute[create #{scenario} talos secrets]"
      subscribes :run, "execute[generate #{scenario} talos configs]"
      subscribes :run, "template[/home/boss/talos/scenarios/#{scenario}/patch-node-#{nodename}.yaml]"
      notifies :run, "execute[copy #{scenario} node config for #{nodename}]", :immediately
      notifies :run, "execute[finalize talos config for #{scenario}]", :delayed
    end

    execute "copy #{scenario} node config for #{nodename}" do
      command "cp /home/boss/talos/scenarios/#{scenario}/node-#{nodename}.yaml /var/www/html/nodes-ipxe/#{scenario}/"
      action :nothing
    end

    kernel_ip_params=[
      n['ip'],
      "",
      node['labinator']['network']['gateway'],
      node['labinator']['network']['netmask'],
      nodename,
      node['labinator']['network']['talos_netdev'],
      "none",
      node['labinator']['network']['dns'],
      "",
      node['labinator']['network']['ntp'],
    ]

    file "/var/www/html/nodes-ipxe/#{scenario}/#{hexhyp}.ipxe" do
      content <<-EOF.gsub(/^\s+/, '').gsub(/ +/, ' ')
        #!ipxe
        kernel /assets/talos-vmlinuz-amd64.xz initrd=talos-initramfs-amd64.xz \
          talos.platform=metal \
          console=tty0 \
          init_on_alloc=1 \
          slab_nomerge \
          pti=on \
          consoleblank=0 \
          nvme_core.io_timeout=4294967295 \
          printk.devkmsg=on \
          ima_template=ima-ng ima_appraise=fix ima_hash=sha512 \
          ip=#{kernel_ip_params.join(":")} \
          talos.config=http://boss.local/nodes-ipxe/#{scenario}/node-#{nodename}.yaml \

        initrd /assets/talos-initramfs-amd64.xz
        boot
      EOF
    end
  end #End nodes

  execute "finalize talos config for #{scenario}" do
    command "\
      talosctl \
        --talosconfig /home/boss/talos/talosconfig
        config remove #{scenario} \
      ; \
      talosctl \
        --talosconfig /home/boss/talos/scenarios/#{scenario}/talosconfig \
        config endpoint #{controlplane_ips.join(" ")} \
      && \
        talosctl \
        --talosconfig /home/boss/talos/scenarios/#{scenario}/talosconfig \
        config node #{all_ips.join(" ")} \
      && \
        talosctl \
        --talosconfig /home/boss/talos/talosconfig \
        config merge /home/boss/talos/scenarios/#{scenario}/talosconfig
    "
    action :nothing
  end
end

=begin
template '/usr/local/bin/mkvmlab.sh' do
  source 'talos-netboot/mkvmlab.sh.erb'
  mode '0755'
  variables(
    network: node['labinator']['network'],
    nodes: node['labinator']['nodes'],
  )
end
=end
