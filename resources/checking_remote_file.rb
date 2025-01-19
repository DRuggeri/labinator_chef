unified_mode true

require 'json'

provides :checking_remote_file

property :path, String, name_property: true
property :source, String, required: true
property :owner, String
property :mode, String
property :group, String
property :check_interval, Integer, default: 60 * 60 * 24 * 14

def whyrun_supported?
  true
end

action :create do
  metadata_file = "#{new_resource.path}.metadata"
  metadata = {
    'next_check' => Time.new(0),
  }

  if ::File.exist?(metadata_file)
    metadata = JSON.parse(::File.read(metadata_file))
    metadata['next_check'] = Time.parse(metadata['next_check'])
    if new_resource.source == metadata['source']
      return if new_resource.check_interval < 0 || Time.now < metadata['next_check']
    end
  end


  converge_by('check or place file and update metadata') do
    metadata['source'] = new_resource.source

    remote_file new_resource.path do
      source new_resource.source
      owner new_resource.owner if new_resource.owner
      group new_resource.group if new_resource.group
      mode new_resource.mode if new_resource.mode
      backup false
    end

#    ruby_block "update #{::File.basename(new_resource.source)} metadata" do
#      block do
        metadata['next_check'] = Time.now + new_resource.check_interval
        ::File.open(metadata_file, 'w') do |f|
          f.write(metadata.to_json)
        end
#      end
#    end
  end
end

action :delete do
  [
    new_resource.path,
    "#{new_resource.path}.metadata"
  ].each do |fname|
    file fname do
      action :delete
    end
  end
end
