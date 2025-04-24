# Connman really doesn't do well when Docker is on the box
file '/etc/apt/preferences' do
  content <<-EOF.gsub(/^    /, '')
    Package: connman-gtk
    Pin: release *
    Pin-Priority: -1

    Package: connman
    Pin: release *
    Pin-Priority: -1
  EOF
end

remote_directory '/home/boss' do
  source 'boss/desktopconfigs'
  owner 'boss'
  group 'boss'
  files_owner 'boss'
  files_group 'boss'
  purge false
  notifies :run, "execute[reset-home-perms]", :immediately
end

execute 'reset-home-perms' do
  command 'chown -R boss:boss /home/boss/.config /home/boss/.xsessionrc'
  action :nothing
end

# Set up autologin and start VNC
directory '/etc/lightdm'
file '/etc/lightdm/lightdm.conf' do
  content <<-EOF.gsub(/^    /, '')
    [LightDM]
    start-default-seat=true

    [Seat:*]
    autologin-guest=false
    autologin-user=boss
    autologin-user-timeout=5
    autologin-in-background=false
    autologin-session=default

    [XDMCPServer]

    [VNCServer]
    enabled=false
    command=/usr/bin/x11vnc -auth guess -display :0 -rfbauth /etc/x11vnc.pass
    port=5900
  EOF
  notifies :restart, "service[lightdm]", :delayed
end

# Prepare Firefox to trust the local CA and set some basic prefs
directory '/etc/firefox/policies'
file '/etc/firefox/policies/policies.json' do
  content <<-EOF.gsub(/^    /, '')
    {
      "policies": {
        "Bookmarks": [],
        "ManagedBookmarks": [],
        "Certificates": {
          "Install": ["/etc/ssl/certs/root_ca.crt"]
        },
        "DisplayBookmarksToolbar": "newtab",
        "DisplayMenuBar": "default-off",
        "Homepage": {
          "URL": "https://boss.local:3000/grafana/d/otelcol-contrib-hostmetrics/opentelemetry-collector-hostmetrics-node-exporter?kiosk=true&orgId=1&from=now-15m&to=now&timezone=browser&var-DS_PROMETHEUS=default&var-service_namespace=agent&var-host=boss&var-diskdevices=[a-z]%2B|nvme[0-9]%2Bn[0-9]%2B|mmcblk[0-9]%2B&refresh=5s",
          "Locked": true,
          "StartPage": "homepage"
        },
        "NoDefaultBookmarks": true
      }
    }
  EOF
end

# Use apt_package to avoid installing all the recommends (including connman)
apt_package 'lxde' do
  options [ '--no-install-recommends' ]
  action :install
end

file '/usr/local/bin/launchWindow.sh' do
  content <<-EOF.gsub(/^    /, '')
    #!/bin/bash
    set -e
    
    export XAUTHORITY=/home/boss/.Xauthority DISPLAY=:0

    POSITION="0,0,800,50,50"

    if [ "$1" = "top" -o "$1" = "bottom" ];then
      if [ "$1" = "top" ];then
        POSITION="0,0,0,50,50"
      fi
      shift
    fi

    CURID=`wmctrl -l | tail -1 | awk '{print $1}'`
    ID=$CURID

    #Launch the program
    "$@" &

    while [ "$ID" == "$CURID" ];do
      #Get its window ID
      ID=`wmctrl -l | tail -1 | awk '{print $1}'`
      sleep 1
    done

    #Disable fullscreen
    wmctrl -i -r $ID -b remove,fullscreen

    #Move to where it should be
    wmctrl -i -r $ID -e $POSITION

    #Set back to full screen
    wmctrl -i -r $ID -b add,fullscreen
  EOF
  mode '0755'
end

[
  'xserver-xorg',
  'xinput',
  'unclutter',
  'x11vnc',
  'lightdm',
  'wmctrl',
  'xfce4-power-manager',
  'firefox-esr',
].each do |name|
  package name do
    action :install
  end
end

#VNC server
systemd_unit 'x11vnc.service' do
  content <<-EOU.gsub(/^    /, '')
    [Unit]
    Description=x11vnc VNC Server for X11
    Requires=lightdm.service
    After=lightdm.service

    [Service]
    Type=simple
    ExecStart=/usr/bin/x11vnc -auth /var/run/lightdm/root/:0 -display WAIT:0 -forever -shared -passwd pass -rfbport 5900
    ExecStop=/usr/bin/killall x11vnc
    Restart=on-failure
    RestartSec=2
    SuccessExitStatus=3
    TimeoutStopSec=5

    [Install]
    WantedBy=graphical.target
  EOU
  triggers_reload true

  action [:create, :enable]
  notifies :restart, "service[x11vnc]", :delayed
end

#Enable services I do want
[
  'lightdm',
  'x11vnc',
].each do |name|
  service name do
    action [:enable, :start]
  end
end
