require 'chef/nexus'
require "#{File.dirname(__FILE__)}/../../../config.rb"

nexus 'chef-nexus rspec test' do
  nexus_url NEXUS_URL
  nexus_repo NEXUS_REPO
  nexus_auth NEXUS_AUTH
  use_auth USE_AUTH

  upload_pom true
  update_if_exists true

  coordinates 'chef-nexus-rspec-test.sub:artifact:jar:1.0.0'
  local_file '/tmp/chef_nexus_rspec_temp/has_extension.test'
end
