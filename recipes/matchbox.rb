step_cert 'matchbox'
[ 'assets', 'profiles', 'groups', 'ignition', 'cloud', 'generic' ].each do |dir|
  directory "/var/lib/matchbox/#{dir}" do
    recursive true
  end
end

systemd_unit 'matchbox.service' do
  content <<-EOU.gsub(/^    /, '')
    [Unit]
    Description=Matchbox
    After=docker.service
    Requires=docker.service

    [Service]
    ExecStartPre=-/usr/bin/docker stop %n
    ExecStartPre=-/usr/bin/docker rm %n
    ExecStart=/usr/bin/docker run --rm \\
                --name %n \\
                --net=host \
                -v /etc/ssl/certs/matchbox.pem:/etc/matchbox/server.crt:ro \\
                -v /etc/ssl/private/matchbox.key:/etc/matchbox/server.key:ro \\
                -v /etc/ssl/certs/root_ca.crt:/etc/matchbox/ca.crt:ro \\
                -v /var/lib/matchbox:/var/lib/matchbox:Z \\
                quay.io/poseidon/matchbox:v#{node['labinator']['versions']['matchbox']} \\
                -address=0.0.0.0:8080 \\
                -rpc-address=0.0.0.0:8081 \\
                -cert-file=/etc/matchbox/server.crt \\
                -key-file=/etc/matchbox/server.key \\
                -ca-file=/etc/matchbox/ca.crt \\
                -assets-path=/var/lib/matchbox/assets \\
                -data-path=/var/lib/matchbox \\
                -log-level=trace
    Restart=on-failure
    TimeoutStopSec=5
    ExecReload=/bin/kill -HUP $MAINPID

    [Install]
    WantedBy=multi-user.target
  EOU
  triggers_reload true
  action :create
  notifies :restart, 'service[matchbox]', :delayed
end

service 'matchbox' do
  action [:enable, :start]
end


remote_archive 'https://go.dev/dl/go1.23.4.linux-amd64.tar.gz' do
  directory '/usr/local'
  check_interval 60 * 60 * 24 * 90
end
  
bash 'build bootcmd' do
  code <<-EOF
    cd /var/tmp
    git clone -b v#{node['labinator']['versions']['matchbox']} https://github.com/poseidon/matchbox.git
    cd matchbox/cmd/bootcmd
    /usr/local/go/bin/go build
    mv bootcmd /usr/bin/
    rm -rf /var/tmp/matchbox
  EOF
  live_stream true
  not_if { ::File.exist?('/usr/bin/bootcmd') }
end


file '/var/lib/matchbox/groups/default.json' do
  content '{ "id": "default", "name": "default", "profile": "default" } '
  verify 'jq . %{path}'
end

file '/var/lib/matchbox/profiles/default.json' do
content '
{
  "id": "default",
  "name": "default",
  "boot": {
    "kernel": "/assets/debianlive-vmlinuz",
    "initrd": ["/assets/debianlive-initrd.img"],
    "args": [
      "initrd=debianlive-initrd.img",
      "root=/dev/nfs",
      "boot=live",
      "netboot=nfs",
      "fetch=http://boss.local/assets/debianlive-filesystem.squashfs"
    ]
  }
}
'
  verify 'jq . %{path}'
end

file '/var/lib/matchbox/profiles/controlplane.json' do
content '
{
  "id": "control-plane",
  "name": "control-plane",
  "boot": {
    "kernel": "/assets/talos-vmlinuz-amd64.xz",
    "initrd": ["/assets/talos-initramfs-amd64.xz"],
    "args": [
      "initrd=initramfs.xz",
      "init_on_alloc=1",
      "slab_nomerge",
      "pti=on",
      "console=tty0",
      "printk.devkmsg=on",
      "talos.platform=metal",
      "talos.config=http://boss.local/assets/controlplane.yaml"
    ]
  }
}
'
  verify 'jq . %{path}'
end

file '/var/lib/matchbox/profiles/worker.json' do
content '
{
  "id": "worker",
  "name": "worker",
  "boot": {
    "kernel": "/assets/talos-vmlinuz-amd64.xz",
    "initrd": ["/assets/talos-initramfs-amd64.xz"],
    "args": [
      "initrd=initramfs.xz",
      "init_on_alloc=1",
      "slab_nomerge",
      "pti=on",
      "console=tty0",
      "printk.devkmsg=on",
      "talos.platform=metal",
      "talos.config=http://boss.local/assets/worker.yaml"
    ]
  }
}
'
  verify 'jq . %{path}'
end