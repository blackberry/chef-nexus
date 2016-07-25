require 'chef/nexus'
require "#{File.dirname(__FILE__)}/../../../config.rb"

nexus 'chef-nexus rspec test' do
  nexus_url NEXUS_URL
  nexus_repo NEXUS_REPO
  nexus_auth NEXUS_AUTH
  use_auth USE_AUTH

  coordinates 'chef-nexus-rspec-test.sub.subsub:artifact:jar:classifier:1.0.0'
  action :delete
end
