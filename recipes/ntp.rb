package 'ntp'

file '/etc/ntpsec/ntp.conf' do
  content '
driftfile /var/lib/ntpsec/ntp.drift
leapfile /usr/share/zoneinfo/leap-seconds.list

pool 0.debian.pool.ntp.org iburst
pool 1.debian.pool.ntp.org iburst
pool 2.debian.pool.ntp.org iburst
pool 3.debian.pool.ntp.org iburst

# Local time is treated as the fallback w/ stratum 4
server  127.127.1.1 iburst
fudge   127.127.1.1 stratum 4

restrict default nomodify
unrestrict default noquery limited

restrict 127.0.0.1
restrict ::1

logconfig +all
'
  notifies :restart, 'service[ntpsec]', :immediately
end

service 'ntpsec' do
  action [ :enable, :start ]
end