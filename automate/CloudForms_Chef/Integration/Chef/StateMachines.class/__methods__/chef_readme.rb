=begin
 chef_readme.rb

 Author: Kevin Morey <kevin@redhat.com>

 Description: Chef integration requires that the knife client be installed and 
   properly configured on each appliance with the automate role.
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

# Steps to install and configure knife:

# 1. Install Chef Client (latest version)
curl -LO https://omnitruck.chef.io/install.sh && sudo bash ./install.sh && rm -rf install.sh

# a) You can also specify a specific Chef version

curl -LO https://omnitruck.chef.io/install.sh && sudo bash ./install.sh -v 11.10.4 && rm -rf install.sh

# 2. Create the .chef directory
mkdir /root/.chef 
   
# 3. copy client_key (i.e. root.pem) file to the .chef directory. 

# 4. create /root/.chef/knife.rb file. 
#    NOTE: knife.rb must be correctly configured. More info: https://docs.chef.io/config_rb_knife.html
#    SAMPLE: below is a sample from a working knife.rb file with bare minimum settings
cat << EOF > /root/.chef/knife.rb
node_name                'root'
client_key               '/root/.chef/root.pem'
chef_server_url          'https://mychefserver.com:443'
ssl_verify_mode          :verify_none
EOF

# 4. Test the knife client - If the knife command below executes without error you are all set. 
knife  node   list

# 5. TroubleShooting:
If knife is not working it is most likely related to:
a) knife.rb file is not configured
b) client_key (i.e. root.pem) is not valid
