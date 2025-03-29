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

# Set up dual-monitor
directory '/home/boss/.config/autostart' do
  recursive true
  owner 'boss'
  group 'boss'
end

file '/home/boss/.config/autostart/lxrandr-autostart.desktop' do
  content <<-EOF.gsub(/^    /, '')
    [Desktop Entry]
    Type=Application
    Name=LXRandR autostart
    Comment=Start xrandr with settings done in LXRandR
    Exec=sh -c 'xrandr --output HDMI-1 --mode 1024x600 --rate 60.04 --output eDP-1 --mode 1024x768 --rate 60.00 --below HDMI-1'
    OnlyShowIn=LXDE
  EOF
end

# Fix touchscreen input maps
file '/home/boss/.xsessionrc' do
  content <<-EOF.gsub(/^    /, '')
    xinput map-to-output 10 HDMI-1
    xinput map-to-output 11 eDP-1
  EOF
  owner 'boss'
  group 'boss'
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

# Use apt_package to avoid installing all the recommends (including connman)
apt_package 'lxde' do
  options [ '--no-install-recommends' ]
  action :install
end

[
  'xserver-xorg',
  'xinput',
  'x11vnc',
  'lightdm',
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
