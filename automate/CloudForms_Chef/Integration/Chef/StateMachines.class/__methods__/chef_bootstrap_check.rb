=begin
 chef_bootstrap_check.rb

 Author: Kevin Morey <kevin@redhat.com>

 Description: This method checks to see if the VM has already been bootstrapped
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

def get_chef_environment_name
  chef_environment = $evm.object['chef_environment']
  chef_environment ||= $evm.root['dialog_chef_environment']
  chef_environment ||= @task.get_tags[:chef_environment] if @task
  chef_environment ||= "_default"
  log(:info, "chef_environment: #{chef_environment}")
  return chef_environment_name
end

def get_domain_suffix
  domain_suffix   = nil
  domain_suffix ||= $evm.object['domain_suffix']
  domain_suffix ||= $evm.root['dialog_domain_suffix']
  domain_suffix ||= @task.get_tags[:domain_suffix] if @task
  log(:info, "domain_suffix: #{domain_suffix}")
  return domain_suffix
end

def get_chef_node_name
  chef_node_name = "#{@vm.name}"
  unless get_domain_suffix.nil?
    chef_node_name = "#{@vm.name}.#{get_domain_suffix}"
  end
  return chef_node_name
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
      log(:info, "exit_status: #{result.exit_status}")
      log(:info, "output: #{result.output}")
      log(:info, "error: #{result.error.inspect}")
      return result
    }
  rescue => timeout
    log(:error, "Error executing chef: #{timeout.class} #{timeout} #{timeout.backtrace.join("\n")}")
    return false
  end
end

begin
  @task = $evm.root['miq_provision']
  @vm = @task.try(:destination) || $evm.root['vm']

  chef_bootstrap_attribute = "CHEF Bootstrapped"

  chef_node_show_command = "/usr/bin/knife node show #{get_chef_node_name} "
  # chef_node_show_command = "/usr/bin/knife node show #{get_chef_node_name} -a name -a chef_environment -F json"

  chef_node_show_response = call_chef(chef_node_show_command)
  log(:info, "chef_node_show_response: #{chef_node_show_response}")
  if chef_node_show_response.success?
    bootstrapped = 'true'
    log(:info, "vm: #{get_chef_node_name} already exists in chef server")
  else
    bootstrapped = 'false'
    log(:info, "vm: #{get_chef_node_name} not found in chef server")
  end
  log(:info, "set_state_var: {#{chef_bootstrap_attribute}=>bootstrapped}")
  $evm.set_state_var(chef_bootstrap_attribute, bootstrapped)
  @vm.custom_set(chef_bootstrap_attribute, bootstrapped)

  # Ruby rescue
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
