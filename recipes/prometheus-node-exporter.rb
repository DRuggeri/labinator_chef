remote_archive "https://github.com/prometheus/node_exporter/releases/download/v#{node['labinator']['versions']['prometheus-node-exporter']}/node_exporter-#{node['labinator']['versions']['prometheus-node-exporter']}.linux-amd64.tar.gz" do
  directory '/usr/local/bin'
  files '*/node_exporter'
  strip_components 1
  notifies :restart, 'service[prometheus-node-exporter]', :delayed
end

systemd_unit 'prometheus-node-exporter.service' do
  content <<-EOU.gsub(/^\s+/, '')
    [Unit]
    Description=Prometheus exporter for machine metrics

    [Service]
    User=monitors
    Group=monitors
    ExecStart=/usr/local/bin/node_exporter
    TimeoutStopSec=5s
    Restart=on-failure

    [Install]
    WantedBy=multi-user.target
  EOU
  triggers_reload true
  action [:create, :enable]
end

service 'prometheus-node-exporter' do
  action [:enable, :start]
end