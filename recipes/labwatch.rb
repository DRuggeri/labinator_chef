directory '/root/go/src/github.com/DRuggeri' do
  recursive true
end

file '/etc/monitors/labwatch.yaml' do
  content <<-EOU.gsub(/^    /, '')
    loki-address: boss.local:3100
    talos-config: /home/boss/talos/talosconfig
    talos-cluster: physical
  EOU
end

git '/root/go/src/github.com/DRuggeri/labinator_labwatch' do
  repository 'https://github.com/DRuggeri/labinator_labwatch.git'
  notifies :run, 'execute[build labwatch]', :immediately
end

execute 'build labwatch' do
  command 'go build -o /usr/local/bin/labwatch'
  cwd '/root/go/src/github.com/DRuggeri/labinator_labwatch'
  notifies :restart, 'service[labwatch]', :delayed
end

systemd_unit 'labwatch.service' do
  content <<~EOU
    [Unit]
    Description=Labwatch labinator awesomeness
    Requires=lightdm.service
    After=lightdm.service

    [Service]
    User=boss
    Group=boss
    Environment=XAUTHORITY=/home/boss/.Xauthority
    Environment=DISPLAY=:0
    ExecStart=/usr/local/bin/labwatch -c /etc/monitors/labwatch.yaml
    Restart=always

    [Install]
    WantedBy=graphical.target
  EOU

  triggers_reload true
  action [:create, :enable]
  notifies :restart, "service[labwatch]", :delayed
end

service 'labwatch' do
  action :start
end