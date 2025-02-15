step_cert 'loki' do
  owner 'monitors'
  group 'monitors'
end

file '/etc/monitors/loki.yml' do
  content '
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096
  http_tls_config:
    cert_file: /etc/ssl/certs/loki.pem
    key_file: /etc/ssl/private/loki.key
  register_instrumentation: true
  log_level: warn #[debug, info, warn, error]

common:
  path_prefix: /data/loki
  storage:
    filesystem:
      chunks_directory: /data/chunks
      rules_directory: /data/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

limits_config:
  allow_structured_metadata: true
  reject_old_samples: false
  reject_old_samples_max_age: 24h
  retention_period: &retention_period 30d

frontend:
  max_outstanding_per_tenant: 4096

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

schema_config:
  configs:
    - from: 2023-01-05
      index:
        period: 24h
        prefix: index_
      object_store: filesystem
      schema: v13
      store: tsdb

compactor:
  working_directory: /data/retention
  delete_request_store: filesystem
  compaction_interval: 10m
  retention_enabled: true
  retention_delete_delay: 2h
  retention_delete_worker_count: 150

table_manager:
  retention_deletes_enabled: true
  retention_period: *retention_period
'
  notifies :restart, 'service[loki]', :delayed
end

directory '/var/lib/loki' do
  owner 'monitors'
  group 'monitors'
end

systemd_unit 'loki.service' do
  content <<-EOU.gsub(/^    /, '')
    [Unit]
    Description=Grafana Loki
    After=network.target
    After=docker.service
    Requires=docker.service

    [Service]
    ExecStartPre=-/usr/bin/docker stop %n
    ExecStartPre=-/usr/bin/docker rm %n
    ExecStart=/usr/bin/docker run --rm \\
      --name %n \\
      -u 1001:1001 \\
      -p 3100:3100 \\
      -v /etc/monitors/loki.yml:/loki-config.yml:ro \\
      -v /etc/ssl/certs/loki.pem:/etc/ssl/certs/loki.pem:ro \\
      -v /etc/ssl/private/loki.key:/etc/ssl/private/loki.key:ro \\
      -v /etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro \\
      -v /etc/localtime:/etc/localtime:ro \\
      -v /var/lib/loki:/data \\
      docker.io/grafana/loki:#{node['labinator']['versions']['loki']} \\
        -config.file=/loki-config.yml
    Restart=on-failure

    [Install]
    WantedBy=default.target
  EOU

  triggers_reload true
  action [:create, :enable]
  notifies :restart, "service[loki]", :delayed
end

service 'loki' do
  action [:enable, :start]
end


remote_archive "https://github.com/grafana/loki/releases/download/v#{node['labinator']['versions']['loki']}/logcli-linux-amd64.zip" do
  directory '/usr/bin'
  files 'logcli-linux-amd64'
end