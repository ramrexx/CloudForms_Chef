=begin
 chef_clear_attributes.rb

 Author: Kevin Morey <kevin@redhat.com>

 Description: This method clears all custom chef attributes and chef tags from
   a VM.
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

begin
  @task = $evm.root['miq_provision']
  @vm = @task.try(:destination) || $evm.root['vm']

  log(:info, "vm: #{@vm.name} custom attributes: #{@vm.custom_keys}")
  @vm.custom_keys.each {|ck| @vm.custom_set(ck,nil) if ck.downcase.starts_with?('chef') }

  log(:info, "vm: #{@vm.name} tags: #{@vm.tags}")
  @vm.tags.each {|t| @vm.tag_unassign(t) if t.downcase.starts_with?('chef') }

  # Ruby rescue
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
