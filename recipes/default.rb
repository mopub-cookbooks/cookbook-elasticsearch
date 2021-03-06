[Chef::Recipe, Chef::Resource].each { |l| l.send :include, ::Extensions }

Erubis::Context.send(:include, Extensions::Templates)

elasticsearch = "elasticsearch-#{node.elasticsearch[:version]}"

include_recipe "elasticsearch::curl"
node.set['java']['install_flavor']="openjdk"
include_recipe "java"
# Create user and group
#
group node.elasticsearch[:user] do
  action :create
end

user node.elasticsearch[:user] do
  comment "ElasticSearch User"
  home    "#{node.elasticsearch[:dir]}/elasticsearch"
  shell   "/bin/bash"
  gid     node.elasticsearch[:user]
  supports :manage_home => false
  action  :create
end

# FIX: Work around the fact that Chef creates the directory even for `manage_home: false`
bash "remove the elasticsearch user home" do
  user    'root'
  code    "rm -rf  #{node.elasticsearch[:dir]}/elasticsearch"
  only_if "test -d #{node.elasticsearch[:dir]}/elasticsearch"
end

# Create ES directories
#
[ node.elasticsearch[:path][:conf], node.elasticsearch[:path][:logs], node.elasticsearch[:pid_path] ].each do |path|
  directory path do
    owner node.elasticsearch[:user] and group node.elasticsearch[:user] and mode 0755
    recursive true
    action :create
  end
end

# Create data path directories
#
data_paths = node.elasticsearch[:path][:data].is_a?(Array) ? node.elasticsearch[:path][:data] : node.elasticsearch[:path][:data].split(',')

data_paths.each do |path|
  directory path.strip do
    owner node.elasticsearch[:user] and group node.elasticsearch[:user] and mode 0755
    recursive true
    action :create
  end
end

# # Create service
# #
# template "/etc/init.d/elasticsearch" do
#   source "elasticsearch.init.erb"
#   owner 'root' and mode 0755
# end

# service "elasticsearch" do
#   supports :status => true, :restart => true
#   action [ :enable ]
# end

# Download, extract, symlink the elasticsearch libraries and binaries
#
remote_file Chef::Config[:file_cache_path] + "/" + node['elasticsearch']['filename'] do
  source node['elasticsearch']['download_url']
  not_if { ::File.exists?(Chef::Config[:file_cache_path] + "/" + node['elasticsearch']['filename']) }
end

directory "/data/elasticsearch/releases" do
  action :create
  recursive true
  owner node.elasticsearch[:user]
  group node.elasticsearch[:user]
  mode 0755
end

execute "untar elasticsearch" do
  command "tar Cxfz /data/elasticsearch/releases #{Chef::Config[:file_cache_path] + "/" + node['elasticsearch']['filename']}"
  not_if { ::File.exists?("/data/elasticsearch/releases/elasticsearch-#{node['elasticsearch']['version']}/bin/elasticsearch") }
end
link "/data/elasticsearch/current" do
  to "/data/elasticsearch/releases/elasticsearch-#{node['elasticsearch']['version']}"
end

# ark "elasticsearch" do
#   url   node.elasticsearch[:download_url]
#   owner node.elasticsearch[:user]
#   group node.elasticsearch[:user]
#   version node.elasticsearch[:version]
#   has_binaries ['bin/elasticsearch', 'bin/plugin']
#   checksum node.elasticsearch[:checksum]

#   notifies :start,   'service[elasticsearch]'
#   notifies :restart, 'service[elasticsearch]'
# end

# Increase open file limits
#
bash "enable user limits" do
  user 'root'

  code <<-END.gsub(/^    /, '')
    echo 'session    required   pam_limits.so' >> /etc/pam.d/su
  END

  not_if { ::File.read("/etc/pam.d/su").match(/^session    required   pam_limits\.so/) }
end

bash "increase limits for the elasticsearch user" do
  user 'root'

  code <<-END.gsub(/^    /, '')
    echo '#{node.elasticsearch.fetch(:user, "elasticsearch")}     -    nofile    #{node.elasticsearch[:limits][:nofile]}'  >> /etc/security/limits.conf
    echo '#{node.elasticsearch.fetch(:user, "elasticsearch")}     -    memlock   #{node.elasticsearch[:limits][:memlock]}' >> /etc/security/limits.conf
  END

  not_if do
    file = ::File.read("/etc/security/limits.conf")
    file.include?("#{node.elasticsearch.fetch(:user, "elasticsearch")}     -    nofile    #{node.elasticsearch[:limits][:nofile]}") \
    &&           \
    file.include?("#{node.elasticsearch.fetch(:user, "elasticsearch")}     -    memlock   #{node.elasticsearch[:limits][:memlock]}")
  end
end

# Create file with ES environment variables
#
template "elasticsearch-env.sh" do
  path   "#{node.elasticsearch[:path][:conf]}/elasticsearch-env.sh"
  source "elasticsearch-env.sh.erb"
  owner node.elasticsearch[:user] and group node.elasticsearch[:user] and mode 0755

  notifies :restart, 'runit_service[elasticsearch]'
end

# Create ES config file
#
template "elasticsearch.yml" do
  path   "#{node.elasticsearch[:path][:conf]}/elasticsearch.yml"
  source "elasticsearch.yml.erb"
  owner node.elasticsearch[:user] and group node.elasticsearch[:user] and mode 0755

  notifies :restart, 'runit_service[elasticsearch]'
end

# Create ES logging file
#
template "logging.yml" do
  path   "#{node.elasticsearch[:path][:conf]}/logging.yml"
  source "logging.yml.erb"
  owner node.elasticsearch[:user] and group node.elasticsearch[:user] and mode 0755

  notifies :restart, 'runit_service[elasticsearch]'
end
include_recipe 'runit::default'

runit_service 'elasticsearch' do
  default_logger true
end
