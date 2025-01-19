file '/var/www/html/talos-boot.ipxe' do
  content "#!ipxe
chain talos-netboot-ipxe/${mac:hexhyp}.ipxe
"
end
directory '/var/www/html/talos-netboot-ipxe'
directory '/var/www/html/talos-netboot-configs'
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

template '/home/boss/talos/patch-all.yaml' do
  owner 'boss'
  group 'boss'
  mode '0755'
  source 'talos-netboot/patch-all.yaml.erb'
  variables(
    network: node['labinator']['network'],
    nodes: node['labinator']['nodes'],
  )
  notifies :run, 'execute[generate talos configs]'
end

execute 'create talos secrets' do
  login true
  user 'boss'
  group 'boss'
  creates '/home/boss/talos/secrets.yaml'
  command 'talosctl gen secrets -o /home/boss/talos/secrets.yaml'
  notifies :run, 'execute[generate talos configs]'
end

execute 'generate talos configs' do
  login true
  user 'boss'
  group 'boss'
  creates '/home/boss/talos/controlplane.yaml'
  command "talosctl gen config koobs https://koobs.local:6443 \
    --force \
    --with-secrets /home/boss/talos/secrets.yaml \
    --config-patch @/home/boss/talos/patch-all.yaml \
    --output /home/boss/talos \
  "
end

execute 'set talos endpoints' do
  login true
  user 'boss'
  group 'boss'
  #creates '/home/boss/talos/controlplane.yaml'
  command "talosctl \
    --talosconfig /home/boss/talos/talosconfig \
    config endpoint \
    #{node['labinator']['nodes']['c1']['ip']} \
    #{node['labinator']['nodes']['c2']['ip']} \
    #{node['labinator']['nodes']['c3']['ip']} \
  "
end

controlplane_ips = []
all_ips = []
node['labinator']['nodes'].each do |nodename, n|
  controlplane_ips << n['ip'] if n['role'] == 'controlplane'
  all_ips << n['ip']
  hexhyp=n['mac'].gsub(/:/, "-")
  template "/home/boss/talos/patch-node-#{nodename}.yaml" do
    owner 'boss'
    group 'boss'
    source 'talos-netboot/patch-node.yaml.erb'
    variables(
      nodename: nodename,
      n: n,
      network: node['labinator']['network'],
    )
  end

  execute "create final node config for #{nodename}" do
    user 'boss'
    group 'boss'
    login true
    command "talosctl \
      --talosconfig /home/boss/talos/talosconfig \
      machineconfig patch /home/boss/talos/#{n['role']}.yaml \
      --patch @/home/boss/talos/patch-node-#{nodename}.yaml \
      -o /home/boss/talos/node-#{nodename}.yaml \
    "
    creates "/home/boss/talos/node-#{nodename}.yaml"
    subscribes :run, 'template[/home/boss/talos/patch-all.yaml]'
    subscribes :run, 'execute[create talos secrets]'
    subscribes :run, 'execute[generate talos configs]'
    subscribes :run, 'template[/home/boss/talos/patch-node-#{nodename}.yaml]'
    notifies :run, "execute[copy node config for #{nodename}]", :immediately
  end

  execute "copy node config for #{nodename}" do
    command "cp /home/boss/talos/node-#{nodename}.yaml /var/www/html/talos-netboot-configs/"
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
  file "/var/www/html/talos-netboot-ipxe/#{hexhyp}.ipxe" do
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
      talos.config=http://boss.local/talos-netboot-configs/node-#{nodename}.yaml \

    initrd /assets/talos-initramfs-amd64.xz
    boot
  EOF
  end

  # TODO - needed for x86 boxes, or only ARM?
  file "/var/www/html/pxelinux.cfg/01-#{hexhyp}" do
  content <<-EOF.gsub(/^    /, '').gsub(/ +/, ' ')
    MENU TITLE Setup Menu
 
    LABEL linux
      KERNEL /assets/talos-vmlinuz-arm64.xz
      APPEND initrd=/assets/talos-initrd \
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
        talos.config=http://boss.local/talos-netboot-configs/node-#{nodename}.yaml
  EOF
  end
end

execute 'finalize talos config' do
    user 'boss'
    group 'boss'
    login true
    command "talosctl --talosconfig /home/boss/talos/talosconfig \
      config endpoint #{controlplane_ips.join(" ")} \
      && \
      talosctl --talosconfig /home/boss/talos/talosconfig \
      config node #{all_ips.join(" ")} \
    "
end

template '/usr/local/bin/mkvmlab.sh' do
  source 'talos-netboot/mkvmlab.sh.erb'
  mode '0755'
  variables(
    network: node['labinator']['network'],
    nodes: node['labinator']['nodes'],
  )
end
