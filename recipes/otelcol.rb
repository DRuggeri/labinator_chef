step_cert 'otelcol' do
  owner 'monitors'
  group 'monitors'
end

file '/etc/monitors/otelcol.yml' do
  content <<-EOU.gsub(/^    /, '')
    receivers:
      prometheus:
        config:
          scrape_configs:
          - job_name: otel-collector
            scrape_interval: 10s
            static_configs:
            - targets: [ '127.0.0.1:8889' ]
      tcplog:
        listen_address: ':5044'
        operators:
        - id: parselog
          type: json_parser
          timestamp:
            parse_from: attributes.talos-time
            layout_type: gotime
            layout: "2006-01-02T15:04:05Z"
          severity:
            parse_from: attributes.talos-level
        - id: ensurehostname
          type: add
          field: attributes.hostname
          value: unknown
          if: "attributes[\\"hostname\\"] == nil"
        - id: ensureservice
          type: add
          field: attributes.talos-service
          value: kernel
          if: "attributes[\\"talos-service\\"] == nil"
        - id: setresourcehost
          type: move
          from: attributes.hostname
          to: resource.host.name
        - id: setresourceservicename
          type: move
          from: attributes.talos-service
          to: resource.service.name
        - id: setmessage
          type: move
          from: attributes.msg
          to: attributes.message
        - id: removettime
          type: remove
          field: attributes.talos-time
        - id: removelevel
          type: remove
          field: attributes.talos-level
      syslog:
        tcp:
          listen_address: ':601'
          tls:
            cert_file: /etc/ssl/certs/otelcol.pem
            key_file: /etc/ssl/private/otelcol.key
        udp:
          listen_address: ':514'
        protocol: rfc5424
        operators:
        - id: earlyfilter
          type: filter
          expr: attributes.message matches ".*(request filter log output|Log statistics).*"
        - id: killbody
          type: remove
          field: body
        - id: setresourcehost
          type: add
          field: resource.host.name
          value: EXPR(trimSuffix(attributes.hostname, ".home.bitnebula.com"))
        - id: setresourceservicename
          type: copy
          from: attributes.appname
          to: resource.service.name
        - id: parserouter
          type: router
          default: keeper
          routes:
          #- output: filtersetpacketfields
          #  expr: attributes.appname == "filterlog"

        ### Pipeline
        - id: keeper
          type: retain
          fields:
          - attributes.message
          - attributes.priority
          - attributes.appname
        - id: setmessage
          type: move
          from: attributes.message
          to: body.MESSAGE
        - id: setidentifier
          type: move
          from: attributes.appname
          to: body.SYSLOG_IDENTIFIER
        - id: setpriority
          type: move
          from: attributes.priority
          to: body.PRIORITY
    #    - id: outputdumper
    #      type: file_output
    #      path: /tmp/collector.out

    processors:
      batch:
      filter:
      resource/loki:
        attributes:
        - action: insert
          key: loki.resource.labels
          value: host.name, service.name

    exporters:
      prometheus:
        endpoint: ':9124'
        tls:
          cert_file: /etc/ssl/certs/otelcol.pem
          key_file: /etc/ssl/private/otelcol.key
      loki:
        endpoint: 'https://#{node['ipaddress']}:3100/loki/api/v1/push'
        default_labels_enabled:
          exporter: false
          job: false
          instance: false
          level: false

    service:
      telemetry:
        logs:
          level: info #debug, info, warn, error
        metrics:
          level: normal #none, basic, normal, detailed
          address: 127.0.0.1:8889

      pipelines:
        metrics:
          receivers: [ prometheus ]
          processors: []
          exporters: [ prometheus ]
        logs:
          receivers: [ syslog ]
          processors: [ resource/loki, batch ]
          exporters: [ loki ]
        logs/talos:
          receivers: [ tcplog ]
          processors: [ batch ]
          exporters: [ loki ]
  EOU
end

systemd_unit 'otelcol.service' do
  content <<-EOU.gsub(/^    /, '')
    [Unit]
    Description=OpenTelemetry collector
    After=network.target
    After=docker.service
    Requires=docker.service

    [Service]
    ExecStartPre=-/usr/bin/docker stop %n
    ExecStartPre=-/usr/bin/docker rm %n
    ExecStart=/usr/bin/docker run --rm \\
      --name %n \\
      -u 1001:1001 \\
      -p 514:514/udp \\
      -p 601:601 \\
      -p 5044:5044 \\
      -p 9124:9124 \\
      -v /etc/monitors/otelcol.yml:/etc/otelcol.yml:ro \\
      -v /etc/ssl/certs/otelcol.pem:/etc/ssl/certs/otelcol.pem:ro \\
      -v /etc/ssl/private/otelcol.key:/etc/ssl/private/otelcol.key:ro \\
      -v /etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro \\
      docker.io/otel/opentelemetry-collector-contrib:#{node['labinator']['versions']['otelcol']} \\
        --config=file:/etc/otelcol.yml
    Restart=on-failure

    [Install]
    WantedBy=default.target
  EOU

  triggers_reload true
  action [:create, :enable]
  notifies :restart, "service[otelcol]", :delayed
end

service 'otelcol' do
  action [:enable, :start]
end