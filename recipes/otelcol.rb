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
      prometheus/agent:
        config:
          scrape_configs:
          - job_name: otel-collector
            scrape_interval: 5s
            static_configs:
            - targets: [ '127.0.0.1:8889' ]
            metric_relabel_configs:
            - action: labeldrop
              regex: "service_instance_id|service_name"

      hostmetrics/agent:
        collection_interval: 5s
        scrapers:
          cpu:
            metrics:
              system.cpu.logical.count:
                enabled: true
          memory:
            metrics:
              system.memory.utilization:
                enabled: true
              system.memory.limit:
                enabled: true
          load:
          disk:
          filesystem:
            metrics:
              system.filesystem.utilization:
                enabled: true
          network:
          paging:
          processes:
          process:
            mute_process_all_errors: true
            metrics:
              process.cpu.utilization:
                enabled: true
              process.memory.utilization:
                enabled: true
              process.threads:
                enabled: true
              process.paging.faults:
                enabled: true
      
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
          field: 'resource["service.name"]'
          value: 'EXPR(body._SYSTEMD_UNIT ?? body.SYSLOG_IDENTIFIER)'
        - type: retain
          fields:
          - body.PRIORITY
          - body.SYSLOG_IDENTIFIER
          - body.MESSAGE
        - id: setmessage
          type: move
          from: body.MESSAGE
          to: body.message

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
          to: 'resource["host.name"]'
        - id: setresourceservicename
          type: move
          from: attributes.talos-service
          to: 'resource["service.name"]'
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
          #tls:
          #  cert_file: /etc/ssl/certs/otelcol.pem
          #  key_file: /etc/ssl/private/otelcol.key
        udp:
          listen_address: ':514'
        protocol: rfc3164
        operators:
        - id: killbody
          type: remove
          field: body
        - id: setresourcehost
          type: add
          field: 'resource["host.name"]'
          value: EXPR(trimSuffix(attributes.hostname, ".local"))
        - id: setresourceservicename
          type: copy
          from: attributes.appname
          to: 'resource["service.name"]'
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
          to: body.message
        - id: setidentifier
          type: move
          from: attributes.appname
          to: body.SYSLOG_IDENTIFIER
        - id: setpriority
          type: move
          from: attributes.priority
          to: body.PRIORITY
        #- id: outputdumper
        #  type: file_output
        #  path: /tmp/collector.out

      # Local files
      filelog/apacheaccess:
        include:
          - /var/log/apache2/other_vhosts_access.log
        operators:
          - type: regex_parser
            # boss.home.bitnebula.com:80 192.168.122.10 - - [19/Apr/2025:08:16:45 -0500] "GET /talos-netboot-ipxe/16-09-01-1a-f4-30.ipxe HTTP/1.1" 404 488 "-" "iPXE/1.0.0+git-20190125.36a4c85-5.1"
            regex: |-
              ^(?P<vhost>[^:]+):(?P<port>\\d+) (?P<remote>\\S+) (?P<logname>\\S+) (?P<user>\\S+) \\[(?P<ts>[^\\]]+)\\] "(?P<method>\\S+) +(?P<uri>[^ ]+) (?P<httpver>[^"]+)" (?P<code>\\d+) (?P<bytes>\\d+) "(?P<referrer>[^"]+)" "(?P<useragent>[^"]+)"
            timestamp:
              parse_from: attributes.ts
              layout_type: gotime
              layout: '02/Jan/2006:15:04:05 -0700'
          - type: remove
            field: attributes.ts
          - id: setservicename
            type: add
            field: 'resource["service.name"]'
            value: 'apache2'

    processors:
      batch:
      
      resource/agent:
        attributes:
          - action: upsert
            key: service.namespace
            value: agent

      attributes/agent:
        actions:
          - key: service.namespace
            action: upsert
            value: agent
          - key: service.name
            action: upsert
            value: otel-collector

      transform:
        metric_statements:
          - context: datapoint
            statements:
              - set(attributes["host.name"], resource.attributes["host.name"])
              - set(attributes["process.command"], resource.attributes["process.command"])
              - set(attributes["process.command_line"], resource.attributes["process.command_line"])
              - set(attributes["process.executable.name"], resource.attributes["process.executable.name"])
              - set(attributes["process.executable.path"], resource.attributes["process.executable.path"])
              - set(attributes["process.owner"], resource.attributes["process.owner"])
              - set(attributes["process.parent_pid"], resource.attributes["process.parent_pid"])
              - set(attributes["process.pid"], resource.attributes["process.pid"])
            
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

    exporters:
      file/tempfile:
        path: /var/tmplog/otelcol.jsonl
        rotation:
          max_megabytes: 100
          max_backups: 1
      prometheus:
        endpoint: ':9124'
        tls:
          cert_file: /etc/ssl/certs/otelcol.pem
          key_file: /etc/ssl/private/otelcol.key
      otlphttp:
        endpoint: https://#{node['ipaddress']}:3100/otlp

    service:
      telemetry:
        logs:
          level: info #debug, info, warn, error
        metrics:
          level: detailed #none, basic, normal, detailed
          readers:
            - pull:
                exporter:
                  prometheus:
                    host: 127.0.0.1
                    port: 8889

      pipelines:
        metrics/agent:
          receivers: [prometheus/agent, hostmetrics/agent]
          processors: [attributes/agent, resourcedetection, transform]
          exporters: [ prometheus ]
        logs:
          receivers: [ syslog ]
          processors: [ batch ]
          exporters: [ otlphttp, file/tempfile ]
        logs/talos:
          receivers: [ tcplog ]
          processors: [ batch ]
          exporters: [ otlphttp, file/tempfile ]
        logs/journald:
          receivers: [ journald ]
          processors: [ filter, resourcedetection ]
          exporters: [ otlphttp, file/tempfile ]
        logs/apacheaccess:
          receivers: [ filelog/apacheaccess ]
          processors: [ resourcedetection ]
          exporters: [ otlphttp, file/tempfile ]
  EOU
  notifies :restart, "service[otelcol]", :delayed
end

systemd_unit 'otelcol.service' do
  content <<-EOU.gsub(/^    /, '')
    [Unit]
    Description=OpenTelemetry collector
    After=network.target
    After=docker.service
    Requires=docker.service

    [Service]
    ExecStartPre=/usr/bin/rm -f /var/tmplog/otelcol.jsonl
    ExecStartPre=/usr/bin/touch /var/tmplog/otelcol.jsonl
    ExecStart=/usr/bin/otelcol-contrib --config=file:/etc/monitors/otelcol.yml
    Restart=on-failure
    TimeoutStopSec=5

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