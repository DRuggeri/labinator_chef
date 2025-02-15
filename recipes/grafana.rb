group 'grafana' do
  gid 1002
end

user 'grafana' do
  gid 'grafana'
  uid 1002
end

step_cert 'grafana-server' do
  owner 'grafana'
  group 'grafana'
end

checking_remote_file '/usr/share/keyrings/grafana.key' do
  source 'https://apt.grafana.com/gpg.key'
  check_interval 60 * 60 * 24 * 90
end

file '/etc/apt/sources.list.d/grafana.list' do
  content 'deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main'
  notifies :run, "execute[Update apt packages]", :immediately
end

package 'grafana' do
  action :install
end

service 'grafana-server' do
  action [ :enable, :start ]
end

file '/etc/grafana/grafana.ini' do
content '
[server]
http_port = 3000
domain = boss.local
root_url = %(protocol)s://%(domain)s:%(http_port)s/grafana/
serve_from_sub_path = true
cert_key = /etc/ssl/private/grafana-server.key
cert_file = /etc/ssl/certs/grafana-server.pem
protocol = https

[log]
level = warn

[log.console]
level = warn

[security]
disable_gravatar = true

[auth.anonymous]
enabled = true
org_name = Main Org.
org_role = Viewer

[panels]
disable_sanitize_html = true
'
  notifies :restart, 'service[grafana-server]', :delayed
end

file '/etc/grafana/provisioning/datasources/prometheus.yml' do
content '
apiVersion: 1

deleteDatasources:
  - name: Prometheus
    orgId: 1

datasources:
- name: Prometheus
  type: prometheus
  uid: prometheus
  access: proxy
  orgId: 1
  url: https://localhost:9090/prometheus
  isDefault: true
  version: 1
  jsonData:
    timeInterval: 1m
editable: false
'
end

file '/etc/grafana/provisioning/datasources/loki.yml' do
  content '
apiVersion: 1

deleteDatasources:
  - name: Loki
    orgId: 1

datasources:
- name: Loki
  uid: loki
  type: loki
  access: proxy
  orgId: 1
  url: https://localhost:3100
editable: false
'
end

file '/etc/grafana/provisioning/dashboards/grafana-dashboards.yml' do
  content '
apiVersion: 1

providers:
- name: default
  orgId: 1
  folder:
  type: file
  disableDeletion: false
  updateIntervalSeconds: 31557600 #how often Grafana will scan for changed dashboards
  options:
    path: /etc/grafana/provisioning/dashboards/files
'
  notifies :restart, 'service[grafana-server]', :delayed
end

directory '/etc/grafana/provisioning/dashboards/files'

[
  'dashboard-node-exporter.json',
].each do |dashboard_file|
  cookbook_file "/etc/grafana/provisioning/dashboards/files/#{dashboard_file}" do
    source "boss/dashboards/#{dashboard_file}"
    notifies :restart, 'service[grafana-server]', :delayed
  end
end

service 'grafana-server' do
  action [:enable, :start]
  notifies :run, 'execute[reset grafana admin pass]', :delayed
end

execute 'reset grafana admin pass' do
  command 'grafana-cli admin reset-admin-password admin'
  action :nothing
end