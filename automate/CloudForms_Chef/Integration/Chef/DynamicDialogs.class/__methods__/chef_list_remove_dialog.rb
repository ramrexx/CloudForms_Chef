=begin
 chef_list_remove_dialog.rb

 Author: Kevin Morey <kevin@redhat.com>

 Description: This method uses knife to list cookbooks, roles and recipes 
  already assigned to the VM (if any).
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
def log(level, message)
  $evm.log(level, "#{message}")
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

def get_chef_environment_name
  chef_environment_name = $evm.object['chef_environment']
  chef_environment_name ||= $evm.root['dialog_chef_environment']
  chef_environment_name ||= $evm.root['dialog_tag_1_chef_environment']
  chef_environment_name ||= @task.get_tags[:chef_environment] if @task
  chef_environment_name ||= "_default"
  log(:info, "chef_environment_name: #{chef_environment_name}")
  return chef_environment_name
end

def get_chef_type
  chef_type = $evm.object['chef_type']
  chef_type ||= $evm.root['dialog_chef_type']
  chef_type ||= "role"
  log(:info, "chef_type: #{chef_type}")
  return chef_type
end

def get_chef_node_name
  chef_node_name   = (@vm.hostnames.first rescue nil)
  chef_node_name ||= @vm.name
  log(:info, "chef_node_name: #{chef_node_name}")
  return chef_node_name
end

$evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}

@vm = $evm.root['vm']
if @vm
  # get current run list
  current_run_list = []
  chef_node_name = get_chef_node_name
  current_run_list_cmd = "/usr/bin/knife node show #{chef_node_name} -r -l -F json"
  current_run_list_result = call_chef(current_run_list_cmd, 20)
  if current_run_list_result.success?
    current_run_list = JSON.parse(current_run_list_result.output)["#{chef_node_name}"]["run_list"]
    log(:info, "current_run_list: #{current_run_list}")
  end
end

dialog_hash = {}

chef_type = get_chef_type

chef_cmd = "/usr/bin/knife #{chef_type} list -E #{get_chef_environment_name} -F json"
result = call_chef(chef_cmd)

if result.success?
  JSON.parse(result.output).sort.each do |item|
    # remove spaces for cookbook and replace with @
    if chef_type == 'cookbook'
      item.gsub!(/\s+/,'@')
    end
    unless current_run_list.blank?
      current_run_list.each do |crl|
        if chef_type == 'cookbook'
          if crl == "recipe[#{chef_type}::#{item}]"
            dialog_hash[item] = "#{chef_type} - #{item}"
          end
        else
          log(:info, "skipping current run_list item: #{item}")
        end
      end
    else
      dialog_hash[item] = "#{chef_type} - #{item}"
    end
  end
end

if dialog_hash.blank?
  dialog_hash[''] = "< no #{chef_type}'s found >"
  $evm.object['required'] = false
else
  $evm.object['default_value'] = dialog_hash.first[0]
end

$evm.object["values"] = dialog_hash
log(:info, "$evm.object['values']: #{$evm.object['values'].inspect}")
