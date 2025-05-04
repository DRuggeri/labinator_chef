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

file '/home/boss/kube/kube-prometheus-stack-values.yaml' do
  content lazy { <<-EOF.gsub(/^    /, '')
    defaultRules:
      create: false
    
    global:
      imageRegistry: #{node['labinator']['network']['mirror_endpoint']}

    alertmanager:
      enabled: false
    
    grafana:
      enabled: false
    
    prometheus:
      service:
        type: NodePort
        nodePort: 30090
  EOF
  }
end

file '/etc/monitors/promsd/kube-prometheus-stack.yaml' do
  owner 'boss'
  group 'boss'
  mode '0644'
end

file '/home/boss/kube/post-install.sh' do
  mode '0755'
  owner 'boss'
  group 'boss'
  content <<-EOF.gsub(/^    /, '')
    #!/bin/bash
    
    helm upgrade --install otelcol-contrib /home/boss/charts/opentelemetry-collector-#{node['labinator']['versions']['otelcolchart']}.tgz --timeout 5m --namespace kube-system -f /home/boss/kube/otelcol-values.yaml
    helm upgrade --install kube-prometheus-stack /home/boss/charts/kube-prometheus-stack-#{node['labinator']['versions']['kube-prometheus-stackchart']}.tgz --timeout 5m --namespace kube-prometheus-stack --create-namespace -f /home/boss/kube/kube-prometheus-stack-values.yaml

    LAB=`curl -sk #{node['labinator']['network']['labwatch_endpoint']}/getlab`
    echo "
    - targets:
      - ${LAB}-workers:30090
    " > /etc/monitors/promsd/kube-prometheus-stack.yaml

  EOF
end