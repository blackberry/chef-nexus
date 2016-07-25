require 'chef/nexus'
require "#{File.dirname(__FILE__)}/../../../config.rb"

nexus 'chef-nexus rspec test' do
  nexus_url NEXUS_URL
  nexus_repo NEXUS_REPO
  nexus_auth NEXUS_AUTH
  use_auth USE_AUTH

  update_if_exists true

  remote_url "#{NEXUS_URL.chomp('/')}/repositories/#{NEXUS_REPO}/chef-nexus-rspec-test/no_parse"
  local_file '/tmp/chef_nexus_rspec_temp/downloaded.test'
  action :download
end
