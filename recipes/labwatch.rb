directory '/root/go/src/github.com/DRuggeri' do
  recursive true
end

file '/etc/monitors/labwatch.yaml' do
  content <<-EOU.gsub(/^    /, '')
    loki-address: boss.local:3100
    loki-query: '{ host_name =~ ".+" } | json'
    loki-trace: false
    talos-config: /home/boss/talos/talosconfig
    talos-cluster: physical
    talos-scenario-config: /home/boss/talos/scenarios/configs.yaml
    talos-scenario-nodes-directory: /home/boss/talos/scenarios
    powermanager-port: /dev/serial/by-id/usb-FTDI_FT232R_USB_UART_A50285BI-if00-port0
    statusinator-port: '/dev/serial/by-id/usb-Espressif_USB_JTAG_serial_debug_unit_98:3D:AE:E9:29:08-if00'
    netboot-folder: /var/www/html/nodes-ipxe/
    netboot-link: lab
    port-watch-trace: false
  EOU
end

git '/root/go/src/github.com/DRuggeri/labinator_labwatch' do
  repository 'https://github.com/DRuggeri/labinator_labwatch.git'
  notifies :run, 'execute[build labwatch]', :immediately
end

execute 'build labwatch' do
  command 'go build -o /usr/local/bin/labwatch'
  cwd '/root/go/src/github.com/DRuggeri/labinator_labwatch'
  notifies :restart, 'service[labwatch]', :delayed
end

systemd_unit 'labwatch.service' do
  content <<~EOU
    [Unit]
    Description=Labwatch labinator awesomeness
    Requires=lightdm.service
    After=lightdm.service

    [Service]
    User=boss
    Group=boss
    Environment=XAUTHORITY=/home/boss/.Xauthority
    Environment=DISPLAY=:0
    ExecStart=/usr/local/bin/labwatch -c /etc/monitors/labwatch.yaml
    Restart=always

    [Install]
    WantedBy=graphical.target
  EOU

  triggers_reload true
  action [:create, :enable]
  notifies :restart, "service[labwatch]", :delayed
end

service 'labwatch' do
  action :start
end