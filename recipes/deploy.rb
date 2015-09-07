# Adapted from deploy::rails: https://github.com/aws/opsworks-cookbooks/blob/master/deploy/recipes/rails.rb

include_recipe 'deploy'

node[:deploy].each do |application, deploy|

  if deploy[:application_type] != 'rails'
    Chef::Log.debug("Skipping opsworks_delayed_job::deploy application #{application} as it is not an Rails app")
    next
  end
  Chef::Log.INFO("Running custom opsworks recipes")

  opsworks_deploy_dir do
    user deploy[:user]
    group deploy[:group]
    path deploy[:deploy_to]
  end

  include_recipe "opsworks_delayed_job::setup"

  file "#{deploy[:deploy_to]}/current/bin/delayed_job" do
    owner deploy[:user]
    group deploy[:group]
    mode 0770
  end

  template "#{deploy[:deploy_to]}/shared/config/memcached.yml" do
    cookbook "rails"
    source "memcached.yml.erb"
    mode 0660
    owner deploy[:user]
    group deploy[:group]
    variables(:memcached => (deploy[:memcached] || {}), :environment => deploy[:rails_env])
  end

  template "#{deploy[:deploy_to]}/shared/config/database.yml" do
    source "database.yml.erb"
    mode 0660
    owner deploy[:user]
    group deploy[:group]
    variables(:database => (deploy[:environment_variables] || {}), :environment => deploy[:rails_env])
  end

  node.set[:opsworks][:rails_stack][:restart_command] = ':'

  opsworks_deploy do
    deploy_data deploy
    app application
  end

  execute "restart delayed_job" do
    command node[:delayed_job][application][:restart_command]
  end

end
