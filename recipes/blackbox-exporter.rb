step_cert 'prometheus-blackbox-exporter' do
  owner 'monitors'
  group 'monitors'
end

remote_archive "https://github.com/prometheus/blackbox_exporter/releases/download/v0.25.0/blackbox_exporter-0.25.0.linux-amd64.tar.gz" do
  directory '/usr/bin'
  strip_components 1
  files '*/blackbox_exporter'
  notifies :restart, 'service[prometheus-blackbox-exporter]', :delayed
end

file '/etc/monitors/blackbox.yml' do
  content <<-EOU
modules:
  http_2xx:
    prober: http
  insecure_http_2xx:
    prober: http
    http:
      tls_config:
        insecure_skip_verify: true
  http_post_2xx:
    prober: http
    http:
      method: POST
  tcp_connect:
    prober: tcp
  pop3s_banner:
    prober: tcp
    tcp:
      query_response:
      - expect: "^+OK"
      tls: true
      tls_config:
        insecure_skip_verify: false
  ssh_banner:
    prober: tcp
    tcp:
      query_response:
      - expect: "^SSH-2.0-"
  irc_banner:
    prober: tcp
    tcp:
      query_response:
      - send: "NICK prober"
      - send: "USER prober prober prober :prober"
      - expect: "PING :([^ ]+)"
        send: "PONG ${1}"
      - expect: "^:[^ ]+ 001"
  icmp:
    prober: icmp
  EOU
end

file '/etc/monitors/blackbox_exporter-web-config.yml' do
  content '
tls_server_config:
  cert_file: /etc/ssl/certs/prometheus-blackbox-exporter.pem
  key_file: /etc/ssl/private/prometheus-blackbox-exporter.key

http_server_config:
  http2: true
'
  notifies :restart, 'service[prometheus-blackbox-exporter]', :delayed
end


systemd_unit 'prometheus-blackbox-exporter.service' do
  content <<-EOU.gsub(/^    /, '')
    [Unit]

    [Service]
    Restart=on-failure
    User=monitors
    Group=monitors
    ExecStart=/usr/bin/blackbox_exporter \\
                --config.file=/etc/monitors/blackbox.yml \\
                --web.config.file=/etc/monitors/blackbox_exporter-web-config.yml \\
                --web.external-url=https://boss.local:9115 \\
                --web.listen-address=0.0.0.0:9115
    ExecReload=/bin/kill -HUP $MAINPID

    [Install]
    WantedBy=multi-user.target
  EOU
  triggers_reload true
  action :create
  notifies :restart, 'service[prometheus-blackbox-exporter]', :delayed
end

service 'prometheus-blackbox-exporter' do
  action [ :enable, :start ]
end