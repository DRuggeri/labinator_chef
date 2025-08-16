[
  '/etc/step-ca',
].each do |dir|
  directory dir do
    mode '0700'
  end
end

remote_archive "https://dl.smallstep.com/gh-release/cli/gh-release-header/v0.28.2/step_linux_0.28.2_amd64.tar.gz" do
  directory '/usr/local/bin'
  strip_components 2
end
remote_archive 'https://dl.smallstep.com/gh-release/certificates/gh-release-header/v0.28.1/step-ca_linux_0.28.1_amd64.tar.gz' do
  directory '/usr/local/bin'
  files  'step-ca'
  notifies :restart, 'service[step-ca]', :delayed
end

file '/etc/step-ca/passphrase' do
  content 's0up3rsEcuR3'
  mode '0700'
end

bash 'initialize step' do
  code <<~EOF
    export STEPPATH=/etc/step-ca
    step ca init --name=lab --dns=boss.local --address=:9000 --deployment-type=standalone --provisioner=boss@ca.lab --password-file=/etc/step-ca/passphrase
    step ca provisioner update "boss@ca.lab" --allow-renewal-after-expiry
    EOF
  not_if { ::File.exist?('/etc/step-ca/certs/root_ca.crt') }
end

ruby_block 'set up certs' do
  block do
    ::FileUtils.cp('/etc/step-ca/certs/root_ca.crt', '/etc/ssl/certs/root_ca.crt')
  end
  not_if { ::File.exist?('/etc/ssl/certs/root_ca.crt') }
  notifies :run, 'execute[update-ca-certificates]', :immediately
end

file '/etc/ssl/certs/root_ca.crt' do
  mode '0744'
end

execute 'update-ca-certificates' do
  command '/usr/sbin/update-ca-certificates'
  action :nothing
end

systemd_unit 'step-ca.service' do
  content <<-EOU.gsub(/^    /, '')
    [Unit]
    Description=Step CA
    After=network.target

    [Service]
    Environment=STEPPATH=/etc/step-ca
    ExecStart=/usr/local/bin/step-ca \
      --password-file /etc/step-ca/passphrase
    Restart=on-failure

    [Install]
    WantedBy=default.target
  EOU

  triggers_reload true
  action [:create, :enable]
  notifies :restart, "service[step-ca]", :delayed
end

service 'step-ca' do
  action [:enable, :start]
end