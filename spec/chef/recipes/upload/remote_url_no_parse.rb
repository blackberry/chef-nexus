# Copyright 2016, BlackBerry Limited
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'chef/nexus'
require "#{File.dirname(__FILE__)}/../../../config.rb"

nexus 'chef-nexus rspec test' do
  nexus_url NEXUS_URL
  nexus_repo NEXUS_REPO
  nexus_auth NEXUS_AUTH
  use_auth USE_AUTH

  remote_url "#{NEXUS_URL.chomp('/')}/repositories/#{NEXUS_REPO}/chef-nexus-rspec-test/no_parse"
  local_file '/tmp/chef_nexus_rspec_temp/no_extension'
  action :upload
end
