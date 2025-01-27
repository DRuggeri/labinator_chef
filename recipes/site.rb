
remote_archive "https://github.com/protocolbuffers/protobuf/releases/download/v#{node['labinator']['versions']['protoc']}/protoc-#{node['labinator']['versions']['protoc']}-linux-x86_64.zip" do
  directory '/usr/bin'
  strip_components 1
  files 'bin/protoc'
end

remote_archive "https://go.dev/dl/go#{node['labinator']['versions']['protoc']}.linux-amd64.tar.gz" do
  directory '/usr/local'
end

file '/etc/profile.d/go.sh' do
  content <<-EOU.gsub(/^\s+/, '')
    export PATH="$PATH:/usr/local/go/bin:$HOME/go/bin"
  EOU
  mode '0755'
end

