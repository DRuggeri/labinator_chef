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

# Enable dual-monitor
# SEE: https://wiki.archlinux.org/title/Multihead
directory '/etc/X11/xorg.conf.d' do
  recursive true
end
file '/etc/X11/xorg.conf.d/10-monitor.conf' do
  content <<-EOF.gsub(/^    /, '')
    Section "Monitor"
      Identifier  "HDMI-2"
      Option      "Primary" "true"
    EndSection

    #Section "Monitor"
    #  Identifier  "HDMI1"
    #  Option      "LeftOf" "VGA1"
    #EndSection
  EOF
end

# Set up autologin
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
