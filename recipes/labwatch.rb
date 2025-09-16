directory '/root/go/src/github.com/DRuggeri' do
  recursive true
end

file '/etc/monitors/labwatch.yaml' do
  content <<-EOU.gsub(/^    /, '')
    loki-address: boss.local:3100
    loki-query: '{ host_name =~ ".+" } | json'
    loki-trace: false
    talos-config: /home/boss/.talos/config
    talos-cluster: physical
    talos-scenario-config: /home/boss/talos/scenarios/configs.yaml
    talos-scenarios-directory: /home/boss/talos/scenarios
    powermanager-port: /dev/serial/by-id/usb-FTDI_FT232R_USB_UART_A50285BI-if00-port0
    statusinator-port: '/dev/serial/by-id/usb-Espressif_USB_JTAG_serial_debug_unit_98:3D:AE:E9:29:08-if00'
    netboot-folder: /var/www/html/nodes-ipxe/
    netboot-link: lab
    port-watch-trace: false
    reliability-test:
      baseUrl: "http://boss.local:8080"
      testInterval: 5
      timeouts:
        "init":                30
        "secret gen":          150
        "disk wipe":           235
        "powerup":             60
        "booting-hypervisors": 245
        "booting-nodes":       235
        "bootstrapping":       155
        "finalizing":          255
        "starting":            156
      preCommand: "sudo /usr/local/bin/labwatch-reliability-test-start.sh"
      postCommand: "sudo /usr/local/bin/labwatch-reliability-test-stop.sh"
  EOU
  notifies :restart, 'service[labwatch]', :delayed
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

file '/usr/local/bin/labwatch-reliability-test-start.sh' do
  content <<-EOU.gsub(/^    /, '')
    #!/bin/bash
    pkill tcpdump
    sleep 2

    rm -rf /var/tmp/testcapture
    mkdir /var/tmp/testcapture
    chown boss:boss /var/tmp/testcapture

    nohup /usr/bin/tcpdump \
      -Z boss  \
      -i enx00e04c687830 \
      -C 100 -W 10 \
      -s 96 \
      -w /var/tmp/testcapture/test.pcap \
      'not (dst host #{node['labinator']['network']['nodes']['boss']['ip']} and tcp dst port 22)
        and
       not (src host #{node['labinator']['network']['nodes']['boss']['ip']} and src port 22)
      ' > /dev/null 2>&1 &
    disown
  EOU
  mode '0755'
end

file '/usr/local/bin/labwatch-reliability-test-stop.sh' do
  content <<-EOU.gsub(/^    /, '')
    #!/bin/bash
    pkill tcpdump
  EOU
  mode '0755'
end