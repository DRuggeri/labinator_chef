unified_mode true

provides :step_cert

property :name, String, name_property: true
property :key_file, [String, nil], default: nil
property :cert_file, [String, nil], default: nil
property :san_names, Array, default: []
property :san_addresses, Array, default: []
property :owner, String, default: 'root'
property :group, String, default: 'root'

def whyrun_supported?
  true
end

action :create do
#Step certs
#SEE: https://smallstep.com/docs/step-ca/renewal/#automated-renewal
systemd_unit 'cert-renewer@.service' do
  content <<-EOF.gsub(/^      /, '')
      [Unit]
      Description=Certificate renewer for %I
      After=network-online.target
      StartLimitIntervalSec=0
      ; PartOf=cert-renewer.target
      After=step-ca.service
      Requires=step-ca.service

      [Service]
      Type=oneshot
      User=root

      Environment=CERT_LOCATION=/etc/ssl/certs/%i.pem
      Environment=KEY_LOCATION=/etc/ssl/private/%i.key

      ExecCondition=/usr/local/bin/step certificate needs-renewal ${CERT_LOCATION}
      ExecStart=/usr/local/bin/step --config=/etc/step-ca/config/defaults.json ca renew --force ${CERT_LOCATION} ${KEY_LOCATION}
      ExecStartPost=/usr/bin/env sh -c "! systemctl --quiet is-active %i.service || systemctl try-reload-or-restart %i"

      [Install]
      WantedBy=multi-user.target
    EOF

    triggers_reload true
    action :create
  end

  systemd_unit 'cert-startup-checker@.service' do
  content <<-EOF.gsub(/^    /, '')
      [Unit]
      Description=Certificate renewer for %I before starting the service
      After=network-online.target
      StartLimitIntervalSec=0
      ; PartOf=cert-renewer.target

      [Service]
      Type=oneshot
      User=root

      Environment=CERT_LOCATION=/etc/ssl/certs/%i.pem
      Environment=KEY_LOCATION=/etc/ssl/private/%i.key

      ExecCondition=/usr/local/bin/step certificate needs-renewal ${CERT_LOCATION}
      ExecStart=/usr/local/bin/step --config=/etc/step-ca/config/defaults.json ca renew --force ${CERT_LOCATION} ${KEY_LOCATION}

      [Install]
      WantedBy=multi-user.target
    EOF

    triggers_reload true
    action :create
  end

  systemd_unit 'cert-renewer@.timer' do
    content <<-EOF.gsub(/^      /, '')
      [Unit]
      Description=Timer for certificate renewal of %I
      ; PartOf=cert-renewer.target

      [Timer]
      Persistent=true

      ; Run the timer unit every 15 minutes.
      OnCalendar=*:1/15

      ; Always run the timer on time.
      AccuracySec=1us

      ; Add jitter to prevent a "thundering hurd" of simultaneous certificate renewals.
      RandomizedDelaySec=5m

      [Install]
      WantedBy=timers.target
    EOF

    triggers_reload true
    action :create
  end

  directory "/etc/systemd/system/#{new_resource.name}.service.d"
  file "/etc/systemd/system/#{new_resource.name}.service.d/override.conf" do
    content <<-EOF.gsub(/^      /, '')
      [Unit]
      After=cert-startup-checker@#{new_resource.name}.service
      Requires=cert-startup-checker@#{new_resource.name}.service
    EOF
  end

  key_file = new_resource.key_file || "/etc/ssl/private/#{new_resource.name}.key"
  cert_file = new_resource.cert_file || "/etc/ssl/certs/#{new_resource.name}.pem"

  new_resource.san_names << "#{node['hostname']}.local"
  new_resource.san_names << node['hostname']
  new_resource.san_names << 'localhost'
  new_resource.san_addresses << '127.0.0.1'
  new_resource.san_addresses << node['ipaddress']
  san_step_args = (new_resource.san_names + new_resource.san_addresses).map { |v| "--san '#{v}'" }.join(" ")

  file key_file do
    owner new_resource.owner
    group new_resource.group
    force_unlink true
    mode 0600
  end

  file cert_file do
    owner new_resource.owner
    group new_resource.group
    force_unlink true
    mode 0644
  end

  if new_resource.owner != 'root'
    group 'ssl-cert' do
      append true
      members new_resource.owner
      action :modify
    end
  end

  file "/var/tmp/stepcertmeta-#{new_resource.name}.txt" do
    content <<-EOF.gsub(/^      /, '')
      name: #{node['hostname']}
      cert_file: #{cert_file}
      key_file: #{key_file}
      owner: #{new_resource.owner}
      group: #{new_resource.group}
      san_step_args: #{san_step_args}
    EOF
    notifies :run, "execute[Create #{new_resource.name} cert key]", :immediately
  end

  execute "Create #{new_resource.name} cert key" do
    command "STEPPATH=/etc/step-ca step ca certificate --force --provisioner-password-file /etc/step-ca/passphrase --provisioner 'boss@ca.lab' #{san_step_args} '#{node['hostname']}' #{cert_file} #{key_file}"
    subscribes :run, "file[#{key_file}]", :immediately

    #Always replace if the file is 24 hours old
    if !::File.exist?(cert_file) || ::File.size(cert_file) == 0 || ::File.mtime(cert_file) < (::Time.now - (60*60*24))
      action :run
    else
      action :nothing
    end
    notifies :restart, "service[#{new_resource.name}]", :delayed
  end

  execute "enable #{new_resource.name} cert renewal timer" do
    command "systemctl enable --now cert-renewer@#{new_resource.name}.timer"
    not_if { ::File.exist?("/etc/systemd/system/timers.target.wants/cert-renewer@#{new_resource.name}.timer") }
  end
end

action :delete do
end
