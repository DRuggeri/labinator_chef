step_cert 'prometheus' do
  owner 'monitors'
  group 'monitors'
end

directory '/var/lib/prometheus/data' do
  owner 'monitors'
  group 'monitors'
  recursive true
end

directory '/etc/monitors' do
  owner 'monitors'
  group 'monitors'
end

file '/etc/monitors/prometheus.yml' do
  content "
global:
  scrape_interval: 10s
  evaluation_interval: 10s
scrape_configs:
  - job_name: prometheus
    scheme: https
    metrics_path: /prometheus/metrics
    tls_config: &tls_config
      ca_file: /etc/ssl/certs/ca-certificates.crt
      insecure_skip_verify: true
    static_configs:
      - targets:
        - boss:9090
  - job_name: loki
    scheme: https
    tls_config: *tls_config
    static_configs:
      - targets:
        - boss:3100
  - job_name: blackbox
    scheme: https
    tls_config: *tls_config
    static_configs:
      - targets:
        - boss:9115
  - job_name: otelcol
    scheme: https
    tls_config: *tls_config
    static_configs:
      - targets:
        - boss:9124
  - job_name: grafana
    scheme: https
    tls_config: *tls_config
    static_configs:
      - targets:
        - boss:3000
"
  notifies :restart, 'service[prometheus]', :delayed
end

file '/etc/monitors/prometheus-web-config.yml' do
content '
tls_server_config:
  cert_file: /etc/prometheus.crt
  key_file: /etc/prometheus.key

http_server_config:
  http2: true
'
end

systemd_unit 'prometheus.service' do
  content <<-EOU.gsub(/^    /, '')
    [Unit]
    Description=Monitoring system and time series database
    After=docker.service
    Requires=docker.service

    [Service]
    ExecStartPre=-/usr/bin/docker stop %n
    ExecStartPre=-/usr/bin/docker rm %n
    ExecStart=/usr/bin/docker run --rm -t \\
                --name %n \\
                --user 1001:1001 \\
                -p 9090:9090 \\
                -v /etc/monitors/prometheus.yml:/etc/prometheus.yml:ro \\
                -v /etc/monitors/prometheus-web-config.yml:/etc/prometheus-web-config.yml:ro \\
                -v /etc/ssl/certs/prometheus.pem:/etc/prometheus.crt:ro \\
                -v /etc/ssl/private/prometheus.key:/etc/prometheus.key:ro \\
                -v /etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro \\
                -v /etc/resolv.conf:/etc/resolv.conf:ro \\
                -v /var/lib/prometheus:/prometheus \\
                docker.io/prom/prometheus:v#{node['labinator']['versions']['prometheus']} \\
                --log.level=debug \\
                --config.file=/etc/prometheus.yml \\
                --web.config.file=/etc/prometheus-web-config.yml \\
                --enable-feature=promql-experimental-functions \\
                --storage.tsdb.retention.time=5y \\
                --web.external-url=https://boss.local:9090/prometheus \\
                --web.enable-admin-api
    Restart=on-failure
    TimeoutStopSec=5
    ExecReload=/bin/kill -HUP $MAINPID

    [Install]
    WantedBy=multi-user.target
  EOU
  triggers_reload true
  action :create
  notifies :restart, 'service[prometheus]', :delayed
end

service 'prometheus' do
  action [:enable, :start]
end