=begin
 chef_bootstrap.rb

 Author: Kevin Morey <kevin@redhat.com>, Dave Costakos <david.costakos@redhat.com>

 Description: This method uses knife to bootstrap a Chef client
-------------------------------------------------------------------------------
   Copyright 2016 Kevin Morey <kevin@redhat.com>

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
-------------------------------------------------------------------------------
=end
def log(level, msg, update_message = false)
  $evm.log(level, "#{msg}")
  @task.message = msg if @task && (update_message || level == 'error')
end

def call_chef(cmd, timeout=20)
  # unset the variables for knife
  pre_cmd = "unset GEM_HOME GEM_PATH IRBRC MY_RUBY_HOME"

  require 'linux_admin'
  require 'timeout'
  begin
    Timeout::timeout(timeout) {
      log(:info, "Executing [#{cmd}] with timeout of #{timeout} seconds")
      result = LinuxAdmin::Common.run("#{pre_cmd};#{cmd}")
      log(:info, "success?: #{result.success?}")
      log(:info, "exit_status: #{result.exit_status}") unless result.exit_status.blank?
      log(:info, "output: #{result.output}")
      log(:info, "error: #{result.error}") unless result.error.blank?
      return result
    }
  rescue => timeout
    log(:error, "Error executing chef: #{timeout.class} #{timeout} #{timeout.backtrace.join("\n")}")
    return false
  end
end

# basic retry logic
def retry_method(retry_time=1.minute)
  log(:info, "Sleeping for #{retry_time} seconds")
  $evm.root['ae_result'] = 'retry'
  $evm.root['ae_retry_interval'] = retry_time
  exit MIQ_OK
end

# process_tags - Dynamically create categories and tags
def process_tags( category, category_description, single_value, tag, tag_description )
  # Convert to lower case and replace all non-word characters with underscores
  category_name = category.to_s.downcase.gsub(/\W/, '_')
  tag_name = tag.to_s.downcase.gsub(/\W/, '_')
  tag_name = tag.gsub(/:/, '_')
  log(:info, "Converted category name:<#{category_name}> Converted tag name: <#{tag_name}>")
  # if the category exists else create it
  unless $evm.execute('category_exists?', category_name)
    log(:info, "Category <#{category_name}> doesn't exist, creating category")
    $evm.execute('category_create', :name => category_name, :single_value => single_value, :description => "#{category_description}")
  end
  # if the tag exists else create it
  unless $evm.execute('tag_exists?', category_name, tag_name)
    log(:info, "Adding new tag <#{tag_name}> description <#{tag_description}> in Category <#{category_name}>")
    $evm.execute('tag_create', category_name, :name => tag_name, :description => "#{tag_description}")
  end
end

def get_chef_environment_name(ws_values={})
  chef_environment = $evm.object['chef_environment']
  chef_environment ||= $evm.root['dialog_chef_environment']
  if @task
    chef_environment = @task.get_tags[:chef_environment] ||
      ws_values[:chef_environment] ||
      @task.get_option(:chef_environment)
  end

  chef_environment ||= "_default"
  log(:info, "chef_environment: #{chef_environment}")
  return chef_environment
end

def get_chef_node_name
  chef_node_name = (@vm.hostnames.first rescue nil)
  if @task
    chef_node_name = @task.get_option(:vm_target_hostname)    
  end

  chef_node_name ||= @vm.name
  log(:info, "chef_node_name: #{chef_node_name}")
  return chef_node_name
end

def get_chef_version(chef_version=nil)
  chef_version ||= $evm.object['chef_version']

  log(:info, "chef_version: #{chef_version}")
  return chef_version
end

begin
  $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}

  @task = $evm.root['miq_provision']
  @vm = @task.try(:destination) || $evm.root['vm']

  chef_bootstrap_attribute = "CHEF Bootstrapped"

  bootstrapped = $evm.get_state_var(chef_bootstrap_attribute)

  chef_environment = get_chef_environment_name
  chef_version = get_chef_version

  chef_ipaddress_attribute = 'Primary IPAddress'
  primary_ipaddress = $evm.get_state_var(chef_ipaddress_attribute)
  log(:info, "vm: #{@vm.name} primary_ipaddress: #{primary_ipaddress}")

  raise "vm: #{@vm.name} primary_ipaddress: #{primary_ipaddress} not present" if primary_ipaddress.blank?

  username = $evm.object['username']
  password = $evm.object.decrypt('password')

  chef_node_name = get_chef_node_name

  unless bootstrapped =~ (/(true|t|yes|y|1)$/i)
    bootstrap_cmd  = "/usr/bin/knife bootstrap #{primary_ipaddress} -x '#{username}' -P '#{password}' "
    bootstrap_cmd += "-E #{chef_environment} -y -N #{chef_node_name} -F json"
    bootstrap_cmd += "--node-ssl-verify-mode none "
    
    if chef_version
      bootstrap_cmd += "--bootstrap-version #{chef_version} "
    end

    bootstrap_result = call_chef(bootstrap_cmd, 300)
    if bootstrap_result.success?
      log(:info, "Successfully bootstrapped #{chef_node_name}", true)
      @vm.custom_set(chef_bootstrap_attribute, 'true')
      process_tags('chef_bootstrapped', "Chef Bootstrapped", true, "true", "True")
      @vm.tag_assign("chef_bootstrapped/true")
    else
      log(:error, "Unable to bootstrap #{chef_node_name}, please check CHEF stacktrace")
      process_tags("chef_bootstrapped", "Chef Bootstrapped", true, "false", "False")
      @vm.tag_assign("chef_bootstrapped/false")
      raise "Exiting due to chef bootstrap failure"
    end
  end

  # Ruby rescue
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
