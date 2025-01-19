step_cert 'apache2'
package 'apache2'
directory '/var/www/html/assets'
directory '/var/www/html/ipxe'
[
  'proxy_http',
  'proxy_connect',
  'proxy_wstunnel',
  'authz_host',
  'ssl',
  'status',
  'headers',
  'rewrite',
].each do |mod|
  execute "enable #{mod}" do
    command "a2enmod #{mod}"
    not_if { ::File.exist?("/etc/apache2/mods-enabled/#{mod}.load") }
    notifies :restart, 'service[apache2]', :delayed
  end
end

file '/etc/apache2/sites-available/000-default.conf' do
  content '
CustomLog "|/usr/bin/logger -t access_log -p user.info" combined
ErrorLog "|/usr/bin/logger -t error_log -p user.warn"

SSLProxyEngine On
SSLProxyCheckPeerCN Off
SSLProxyCheckPeerName Off
SSLProxyCACertificateFile /etc/ssl/certs/root_ca.crt

RewriteEngine On

<Location />
  Require all granted
</Location>

<Location /ipxe>
  RewriteCond %{REQUEST_FILENAME} !-f
  RewriteRule ^ /ipxe/default.ipxe [L]
</Location>

<Location /pxelinux.cfg>
  RewriteCond %{REQUEST_FILENAME} !-f
  RewriteRule ^ /pxelinux.cfg/default [L]
</Location>

<VirtualHost *:80>
</VirtualHost>

<VirtualHost *:443>
  SSLEngine on
  SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
  SSLCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
  SSLHonorCipherOrder off
  SSLSessionTickets off
  SSLOptions +StrictRequire
  SSLCertificateFile /etc/ssl/certs/apache2.pem
  SSLCertificateKeyFile /etc/ssl/private/apache2.key

  ProxyPass /v2 https://127.0.0.1:5000/v2
  ProxyPassReverse /v2 https://127.0.0.1:5000/v2
</VirtualHost>
'
  mode '0755'
  action :create
  notifies :restart, 'service[apache2]', :delayed
end

service 'apache2' do
  action [ :enable, :start ]
end
