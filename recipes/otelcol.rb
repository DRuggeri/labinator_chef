step_cert 'otelcol' do
  owner 'monitors'
  group 'monitors'
end

remote_archive "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v#{node['labinator']['versions']['otelcol']}/otelcol-contrib_#{node['labinator']['versions']['otelcol']}_linux_amd64.tar.gz" do
  directory '/usr/bin'
  files 'otelcol-contrib'
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

      # local log messages
      journald:
        start_at: end
        priority: info
        operators:
        - id: severityconverter
          type: add
          field: attributes.level
          value: 'EXPR(
            let conv = {
              "0": "emergency",
              "1": "alert",
              "2": "critical",
              "3": "error",
              "4": "warning",
              "5": "notice",
              "6": "info",
              "7": "debug",
            };
            conv[body.PRIORITY] ?? "unknown"
          )'
        - id: severity_parser
          type: severity_parser
          parse_from: attributes.level
          if: attributes.level != "unknown"
          mapping:
            fatal4: emergency
            fatal: alert
            error4: critical
            error: error
            warn: warning
            info4: notice
            info: info
            debug: debug
        - id: setservicename
          type: add
          field: resource.service.name
          value: 'EXPR(body._SYSTEMD_UNIT ?? body.SYSLOG_IDENTIFIER)'
        - type: retain
          fields:
          - body.PRIORITY
          - body.SYSLOG_IDENTIFIER
          - body.MESSAGE            

      # Remote log messages
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

      resourcedetection:
        detectors: [ system ]
        system:
          hostname_sources: [ os ]
          resource_attributes:
            host.name:
              enabled: true
            os.type:
              enabled: false
      filter:
        logs:
          log_record:
          # Drop messages that are just arrays of bytes
          - IsMatch(body["MESSAGE"], "^\\\\[")
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
        logs/journald:
          receivers: [ journald ]
          processors: [ filter, resourcedetection, resource/loki, batch ]
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
    ExecStart=/usr/bin/otelcol-contrib --config=file:/etc/monitors/otelcol.yml
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