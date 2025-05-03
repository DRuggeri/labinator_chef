directory '/home/boss/kube' do
  owner 'boss'
  group 'boss'
end

file '/home/boss/kube/otelcol-values.yaml' do
  content lazy { <<-EOF.gsub(/^    /, '')
    mode: daemonset
    image:
      repository: #{node['labinator']['network']['mirror_endpoint']}/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib
      tag: #{node['labinator']['versions']['otelcol']}
    command:
      name: otelcol-contrib
    tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
    presets:
      hostMetrics:
        enabled: true
      kubeletMetrics:
        enabled: true
      kubernetesAttributes:
        enabled: true
      logsCollection:
        enabled: true
    resources:
      limits:
        cpu: 250m
        memory: 128Mi
    config:
      receivers:
        kubeletstats:
          insecure_skip_verify: true
      exporters:
        otlphttp:
          endpoint: https://#{node['labinator']['network']['log_endpoint']}:3100/otlp
          tls:
            ca_pem: |-
#{::File.readlines('/etc/ssl/certs/root_ca.crt').map { |l| "              #{l}"}.join("") }
      service:
        pipelines:
          logs:
            exporters:
              - otlphttp
  EOF
  }
end

file '/home/boss/kube/kube-state-metrics-values.yaml' do
  content lazy { <<-EOF.gsub(/^    /, '')
    image:
      registry: #{node['labinator']['network']['mirror_endpoint']}
      tag: v#{node['labinator']['versions']['kube-state-metrics']}
    service:
      type: NodePort
      nodePort: 30000
  EOF
  }
end

file '/home/boss/kube/post-install.sh' do
  mode '0755'
  owner 'boss'
  group 'boss'
  content <<-EOF.gsub(/^    /, '')
    #!/bin/bash
    
    helm upgrade --install otelcol-contrib /home/boss/charts/opentelemetry-collector-#{node['labinator']['versions']['otelcolchart']}.tgz --timeout 5m --namespace kube-system -f /home/boss/kube/otelcol-values.yaml
    helm upgrade --install kube-state-metrics /home/boss/charts/kube-state-metrics-#{node['labinator']['versions']['kube-state-metricschart']}.tgz --timeout 5m --create-namespace --namespace monitoring -f /home/boss/kube/kube-state-metrics-values.yaml
  EOF
end