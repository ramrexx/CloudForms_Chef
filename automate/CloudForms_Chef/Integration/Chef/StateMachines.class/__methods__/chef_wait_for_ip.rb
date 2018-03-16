=begin
 chef_wait_for_ip.rb

 Author: Kevin Morey <kevin@redhat.com>

 Description: This method checks to ensure that the VM has an IP Address
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

# basic retry logic
def retry_method(retry_time=15.seconds)
  log(:info, "Sleeping for #{retry_time} seconds")
  $evm.root['ae_result'] = 'retry'
  $evm.root['ae_retry_interval'] = retry_time
  exit MIQ_OK
end

def check_ipaddress
  log(:info, "vm.hardware.ipaddresses: #{@vm.try(:hardware).try(:ipaddresses)}")
  log(:info, "vm.ipaddresses: #{@vm.try(:hardware).try(:ipaddresses)}")

  ipaddress = (@vm.try(:hardware).try(:ipaddresses).first || @vm.try(:ipaddresses).first rescue [])
  log(:info, "vm: #{@vm.name} primary IP address: #{ipaddress}")

  if ipaddress.blank? || ipaddress.match(/^(169.254|0)/)
    @vm.refresh
    log(:warn, "vm: #{@vm.name} IP address: #{ipaddress} not present", true)
    retry_method
  end

  log(:info, "vm: #{@vm.name} IP address: #{ipaddress} present", true)
  return ipaddress
end

begin
  $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}

  @task = $evm.root['miq_provision']
  @vm = @task.try(:destination) || $evm.root['vm']

  chef_ipaddress_attribute = 'Primary IPAddress'
  primary_ipaddress = check_ipaddress
  log(:info, "set_state_var: {#{chef_ipaddress_attribute}=>primary_ipaddress}")
  $evm.set_state_var(chef_ipaddress_attribute, primary_ipaddress)

  # Ruby rescue
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_OK
end
