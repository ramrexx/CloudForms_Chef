=begin
 chef_remove_recipe.rb

 Author: Kevin Morey <kevin@redhat.com>, Dave Costakos <david.costakos@redhat.com>

 Description: This method uses knife to remove a recipe from a Chef client
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

def get_chef_recipe(ws_values={})
  chef_recipe = $evm.object['chef_recipe']
  chef_recipe ||= $evm.root['dialog_chef_recipe']
  if @task
    chef_recipe = @task.get_tags[:chef_recipe] ||
      ws_values[:chef_recipe] ||
      @task.get_option(:chef_recipe)
  end

  chef_recipe ||= ""
  log(:info, "chef_recipe: #{chef_recipe}")
  return chef_recipe
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

def update_vm_custom_attributes(output, chef_node_name)
  chef_runlist_attribute = "CHEF Run List"
  run_list = JSON.parse(output)["#{chef_node_name}"]["run_list"]
  log(:debug, "#{chef_runlist_attribute} #{chef_node_name}: #{run_list}")
  @vm.custom_set(chef_runlist_attribute, run_list)
end

begin
  $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}

  @task = $evm.root['miq_provision']
  @vm = @task.try(:destination) || $evm.root['vm']
  
  chef_bootstrap_attribute = "CHEF Bootstrapped"
  bootstrapped = $evm.get_state_var(chef_bootstrap_attribute)

  ws_values = (@task.options.fetch(:ws_values, {}) rescue {})

  chef_recipe = get_chef_recipe(ws_values)
  chef_environment = get_chef_environment_name
  chef_node_name = get_chef_node_name

  exit MIQ_OK if chef_recipe.blank?

  if bootstrapped =~ (/(true|t|yes|y|1)$/i)

    remove_recipe_cmd  = "/usr/bin/knife node run_list remove #{chef_node_name} recipe[#{chef_recipe}] "
    remove_recipe_cmd += "-E #{chef_environment} -F json "
    remove_recipe_result = call_chef(remove_recipe_cmd, 20)

    if remove_recipe_result.success?
      log(:info, "Recipe #{chef_recipe} remove successful", true)
      update_vm_custom_attributes(remove_recipe_result.output, chef_node_name)
    else
      raise "Recipe #{chef_recipe} remove failed"
    end
  end

  # Ruby rescue
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
