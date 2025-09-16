[
  'apt-transport-https',
  'ca-certificates',
  'gnupg2',
  'software-properties-common',
].each do |name|
  package name do
    action :install
  end
end

execute 'Trust Docker key' do
  command 'curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg'
  not_if { ::File.exist?('/usr/share/keyrings/docker-archive-keyring.gpg') }
end

file '/etc/apt/sources.list.d/docker.sources' do
  content <<-EOF.gsub(/^    /, '')
    Types: deb
    URIs: https://download.docker.com/linux/debian
    Suites: #{node['lsb']['codename']}
    Components: stable
    Signed-By: /usr/share/keyrings/docker-archive-keyring.gpg
  EOF
  notifies :run, "execute[Update apt packages]", :immediately
end

file '/etc/apt/sources.list.d/docker.list' do
  action :delete
  notifies :run, "execute[Update apt packages]", :immediately
end

execute 'Update apt packages' do
  command 'apt-get update'
  action :nothing
end

[
  'docker-ce',
  'docker-compose-plugin',
].each do |name|
  package name do
    timeout 900
    action :install
  end
end

directory '/etc/docker/certs.d/boss' do
  recursive true
end
execute '/etc/docker/certs.d/boss/ca.crt' do
  command 'cp /etc/ssl/certs/root_ca.crt /etc/docker/certs.d/boss/ca.crt'
  only_if { !::File.exist?('/etc/docker/certs.d/boss/ca.crt') }
  notifies :restart, "service[docker]", :immediately
end

service 'docker' do
  action :start
end

group 'docker' do
  append true
  members 'boss'
  action :modify
end