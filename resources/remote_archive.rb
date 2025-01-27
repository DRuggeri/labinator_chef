unified_mode true

provides :remote_archive

property :source, String, name_property: true
property :directory, [String, nil]
property :files, [nil, String, Array, Hash]
property :owner, String
property :group, String
property :check_interval, Integer, default: -1
property :strip_components, Integer, default: 0

def whyrun_supported?
  true
end

action :extract do
  if new_resource.directory == nil && (new_resource.files == nil || !new_resource.files.is_a?(Hash))
    raise "directory must be set unless files is a hash"
  end

  safe_name = new_resource.source.gsub(/[^0-9A-Za-z.\-]/, '_')
  local_file = "/var/tmp/#{safe_name}"

  extracts = {}

  if new_resource.files == nil
    extracts = {
      new_resource.directory => nil,
    }
  elsif new_resource.files.is_a?(String)
    extracts = {
      new_resource.directory => [ new_resource.files ],
    }
  elsif new_resource.files.is_a?(Array)
    extracts = {
      new_resource.directory => new_resource.files,
    }
  elsif new_resource.files.is_a?(Hash)
    extracts = new_resource.files
  else
    raise "files is {new_resource.files} - impossibru!!!"
  end

  checking_remote_file local_file do
    source new_resource.source
    check_interval new_resource.check_interval
  end

  extracts.each do |directory, files|
    command = []
    if local_file.downcase.end_with?('.tar.gz') ||
      local_file.downcase.end_with?('.tgz') ||
      local_file.downcase.end_with?('.tar')
      command = [
        "tar", "--directory=#{directory}", "--wildcards",
        "--strip-components=#{new_resource.strip_components}", "-xf", local_file
      ]
      if files
        command += files.is_a?(String) ? [ files ] : files
      end
    elsif local_file.downcase.end_with?('.zip')
      command = [ "unzip", "-o", "-d", directory, local_file ]
      if files
        command += files.is_a?(String) ? [ files ] : files
      end
      raise "cannot strip `#{new_resource.strip_components}` componenets from zip files" if new_resource.strip_components && new_resource.strip_components != 0
    else
      raise "Do not know how to deal with the file #{local_file}"
    end

    execute "extract #{::File.basename(new_resource.source)} #{directory} files" do
      command command
      group new_resource.group if new_resource.group
      user new_resource.owner if new_resource.owner
      subscribes :run, "checking_remote_file[#{local_file}]", :immediately
      action :nothing
    end
  end
end

action :delete do
end
