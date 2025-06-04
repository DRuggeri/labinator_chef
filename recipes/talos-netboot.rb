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

checking_remote_file '/var/www/html/assets/metal-amd64.iso' do
  source "https://github.com/siderolabs/talos/releases/download/v#{node['labinator']['versions']['talos']}/metal-amd64.iso"
  check_interval 60 * 60 * 24 * 90
  mode '0755'
end

directory '/home/boss/talos' do
  owner 'boss'
  group 'boss'
end

directory '/home/boss/talos/scenarios' do
  owner 'boss'
  group 'boss'
end

file '/home/boss/talos/scenarios/configs.yaml' do
  content node['labinator']['talos']['scenario_config']
end

node['labinator']['talos']['scenarios'].each do |scenario, scenario_config|
  [
    "/var/www/html/nodes-ipxe/#{scenario}",
    "/home/boss/talos/scenarios/#{scenario}",
  ].each do |dir|
    directory dir do
      #Set ownership to boss so labwatch can gegnerate configs
      owner 'boss'
      group 'boss'
    end
  end

  template "/home/boss/talos/scenarios/#{scenario}/patch-all.yaml" do
    source 'talos-netboot/patch-all.yaml.erb'
    variables(
      network: node['labinator']['network'],
      nodes: scenario_config['nodes'],
    )
  end
  
  template "/home/boss/talos/scenarios/#{scenario}/generate.sh" do
    source 'talos-netboot/generateTalosConfigs.sh.erb'
    mode '0755'
    variables(
      scenario: scenario,
      nodes: scenario_config['nodes'],
    )
  end

  # Generate per-node configs
  talos_controlplane_ips = []
  all_talos_ips = []
  scenario_config['nodes'].each do |nodename, n|
    hexhyp=n['mac'].gsub(/:/, "-")

    # If these are VM hosts, no need to generate a Talos config and our netboot script is much simpler
    if n['role'] == 'kvm'
      file "/var/www/html/nodes-ipxe/#{scenario}/#{hexhyp}.ipxe" do
        content <<-EOF.gsub(/^\s+/, '').gsub(/ +/, ' ')
          #!ipxe
          kernel /assets/kvm-debianlive-vmlinuz-amd64 initrd=kvm-debianlive-initrd-amd64.img \
            fetch=http://boss.local/assets/kvm-debianlive-filesystem-amd64.squashfs \
            boot=live components \
            ip=dhcp \
            consoleblank=0 \
            console=tty0 \
            kvm-amd.nested=1 \
            kvm-intel.nested=1 \
  
          initrd /assets/kvm-debianlive-initrd-amd64.img
          boot
        EOF
      end
    else
      talos_controlplane_ips << n['ip'] if n['role'] == 'controlplane'
      all_talos_ips << n['ip']

      template "/home/boss/talos/scenarios/#{scenario}/patch-node-#{nodename}.yaml" do
        source 'talos-netboot/patch-node.yaml.erb'
        variables(
          nodename: nodename,
          n: n,
          network: node['labinator']['network'],
        )
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
    end
  end #End nodes
end