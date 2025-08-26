# Talos: talosctl image default
# Kyverno: cat ~/charts/kyverno/values.yaml | yq -r '.. | .image? | select(.repository) | "\(.defaultRegistry)/\(.repository):\(.tag)"' | sort  -u | sed -e 's/^null/docker.io/g' -e "s/:null/:$kyvernoversion/g"
# kube-state-metrics: grep appVersion kube-state-metrics/Chart.yaml
#quay.io/poseidon/matchbox:v#{node['labinator']['versions']['matchbox']}
# helm template kube-prometheus-stack | yq -r '..|.image? | select(.)'     | sort -u
node.default['labinator']['container_images']['static']=%W{
docker.io/registry:2

docker.io/prom/prometheus:v#{node['labinator']['versions']['prometheus']}
docker.io/grafana/loki:#{node['labinator']['versions']['loki']}

ghcr.io/kyverno/background-controller:v#{node['labinator']['versions']['kyverno']}
ghcr.io/kyverno/cleanup-controller:v#{node['labinator']['versions']['kyverno']}
ghcr.io/kyverno/kyverno-cli:v#{node['labinator']['versions']['kyverno']}
ghcr.io/kyverno/kyverno:v#{node['labinator']['versions']['kyverno']}
ghcr.io/kyverno/kyvernopre:v#{node['labinator']['versions']['kyverno']}
ghcr.io/kyverno/reports-controller:v#{node['labinator']['versions']['kyverno']}

docker.io/bitnami/kubectl:1.30.2
docker.io/busybox:1.35

ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib:#{node['labinator']['versions']['otelcol']}

quay.io/prometheus/node-exporter:v#{node['labinator']['versions']['node-exporterimage']}
quay.io/prometheus-operator/prometheus-operator:v#{node['labinator']['versions']['prometheus-operatorimage']}
quay.io/prometheus/prometheus:v#{node['labinator']['versions']['prometheusimage']}
registry.k8s.io/kube-state-metrics/kube-state-metrics:v#{node['labinator']['versions']['kube-state-metricsimage']}
registry.k8s.io/ingress-nginx/kube-webhook-certgen:v#{node['labinator']['versions']['kube-webhook-certgenimage']}
quay.io/prometheus-operator/prometheus-config-reloader:v#{node['labinator']['versions']['prometheus-config-reloaderimage']}
}

bash 'helmcharts' do
  user 'boss'
  group 'boss'
  environment 'HOME' => '/home/boss'
  code <<-EOH
    helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
    helm fetch -d ~/charts open-telemetry/opentelemetry-collector --version #{node['labinator']['versions']['otelcolchart']}

    helm repo add kyverno https://kyverno.github.io/kyverno/
    helm fetch -d ~/charts kyverno/kyverno --version #{node['labinator']['versions']['kyvernochart']}

    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm fetch -d ~/charts prometheus-community/kube-prometheus-stack --version #{node['labinator']['versions']['kube-prometheus-stackchart']}
  EOH
  live_stream true
  creates "/home/boss/charts/opentelemetry-collector-#{node['labinator']['versions']['otelcolchart']}.tgz"
end

ruby_block "get list of talos images" do
  block do
    node.default['labinator']['container_images']['talos'] = shell_out('talosctl image default').stdout.split(/\n/)
  end
end

ruby_block 'combine all image lists' do
  block do
    all = []
    node.default['labinator']['container_images'].each do |name, list|
      all += list
    end
    node.default['labinator']['container_images']['all'] = all
  end
end

ruby_block 'generate mirror script' do
  block do
    img_mirror_cmd = []
    node['labinator']['container_images']['all'].each do |img|
      parts = img.split('/')
      parts[0] = node['labinator']['network']['mirror_endpoint']
      local = parts.join('/')

      img_mirror_cmd << "if [ -z \"$(docker images -q #{local} 2> /dev/null)\" ]; then"
      img_mirror_cmd << "  docker pull #{img}"
      img_mirror_cmd << "  docker tag #{img} #{local}"
      img_mirror_cmd << "  docker push #{local}"
      img_mirror_cmd << "fi"
    end
    node.default['labinator']['container_image_mirror_script'] = img_mirror_cmd.join("\n")
  end
end

# Handy file to hold a list of all mirrored images. If the list changes, the
# heavier weight script to pull/mirror the images will be run
file '/home/boss/mirrored' do
  content lazy { node['labinator']['container_images']['all'].join("\n") }
  notifies :run, 'bash[mirror images]', :immediately
end

bash 'mirror images' do
  code lazy { node['labinator']['container_image_mirror_script'] }
  live_stream true
  action :nothing
end

['counterclient', 'counterserver'].each do |app|
  remote_directory "/home/boss/#{app}" do
    source app
    owner 'boss'
    group 'boss'
    files_owner 'boss'
    files_group 'boss'
    files_mode '0644'
    mode '0755'
    
    action :create
    notifies :run, "bash[build #{app}]", :immediately
  end

  bash "build #{app}" do
    user 'boss'
    group 'boss'
    login true
    code <<-EOH
      cd /home/boss/#{app}
      docker build --tag ghcr.io/druggeri/#{app} .
      docker tag ghcr.io/druggeri/#{app} #{node['labinator']['network']['mirror_endpoint']}/druggeri/#{app}:latest
      docker push #{node['labinator']['network']['mirror_endpoint']}/druggeri/#{app}:latest
    EOH
    live_stream true
    action :nothing
  end
end