step_cert 'registry'

systemd_unit 'registry.service' do
  content <<-EOU.gsub(/^\s+/, '')
    [Unit]
    Description=docker registry
    After=network.target
    After=docker.service
    Requires=docker.service

    [Service]
    ExecStartPre=-/usr/bin/docker stop %n
    ExecStartPre=-/usr/bin/docker rm %n
    ExecStart=/usr/bin/docker run --rm \
      --name %n \
      --net=host \
      -v /etc/ssl/private/registry.key:/certs/registry.key:ro \
      -v /etc/ssl/certs/registry.pem:/certs/registry.pem:ro \
      -v /var/lib/registry:/var/lib/registry \
      -e REGISTRY_HTTP_ADDR=0.0.0.0:5000 \
      -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.pem \
      -e REGISTRY_HTTP_TLS_KEY=/certs/registry.key \
      docker.io/registry:2
    Restart=on-failure

    [Install]
    WantedBy=default.target
  EOU

  triggers_reload true
  action [:create, :enable]
  notifies :restart, "service[registry]", :delayed
end

service 'registry' do
  action [:enable, :start]
end