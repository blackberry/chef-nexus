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

require 'spec_helper'

describe 'Chef::Nexus' do
  ############
  ## UPLOAD ##
  ############

  idempotency_helper(
    'Upload file with extension using coordinates groupId:artifactId:version',
    'upload/extn_groupId:artifactId:version.rb',
    "uploaded file '/tmp/chef_nexus_rspec_temp/has_extension.test' to Nexus at 'http://ebj-pilot-nexus.devlab2k.testnet.rim.net/nexus/content/repositories/ebu-opennebula-images/chef-nexus-rspec-test/artifact/1.0.0/artifact-1.0.0.test'"
  )
  idempotency_helper(
    'Upload file with extension using coordinates groupId:artifactId:packaging:version',
    'upload/extn_groupId:artifactId:packaging:version.rb',
    "uploaded file '/tmp/chef_nexus_rspec_temp/has_extension.test' to Nexus at 'http://ebj-pilot-nexus.devlab2k.testnet.rim.net/nexus/content/repositories/ebu-opennebula-images/chef-nexus-rspec-test/sub/artifact/1.0.0/artifact-1.0.0.jar'"
  )
  idempotency_helper(
    'Upload file with extension using coordinates groupId:artifactId:packaging:classifier:version',
    'upload/extn_groupId:artifactId:packaging:classifier:version.rb',
    "uploaded file '/tmp/chef_nexus_rspec_temp/has_extension.test' to Nexus at 'http://ebj-pilot-nexus.devlab2k.testnet.rim.net/nexus/content/repositories/ebu-opennebula-images/chef-nexus-rspec-test/sub/subsub/artifact/1.0.0/artifact-1.0.0-classifier.jar'"
  )
  describe 'Try to upload a file without package, should fail.' do
    it do
      is_expected.to converge_test_recipe(
        :recipe => 'upload/no_extn_groupId:artifactId:version.rb',
        :expected => 'Files require an extension, or specify it with :packaging',
        :fail_if => 'uploaded file'
      )
    end
  end
  idempotency_helper(
    'Upload file without an extension using package attribute',
    'upload/no_extn_package_groupId:artifactId:version.rb',
    "uploaded file '/tmp/chef_nexus_rspec_temp/no_extension' to Nexus at 'http://ebj-pilot-nexus.devlab2k.testnet.rim.net/nexus/content/repositories/ebu-opennebula-images/chef-nexus-rspec-test/artifact/1.0.1/artifact-1.0.1.pkg'"
  )
  idempotency_helper(
    'Upload file with all coordinate attributes, overriding Maven coordinates',
    'upload/no_extn_coordinate_attributes.rb',
    "uploaded file '/tmp/chef_nexus_rspec_temp/no_extension' to Nexus at 'http://ebj-pilot-nexus.devlab2k.testnet.rim.net/nexus/content/repositories/ebu-opennebula-images/chef-nexus-rspec-test/artifact/1.2/artifact-1.2-classifier.pkg'"
  )
  describe 'Try to upload a different file to one that already exists on Nexus, should fail.' do
    it do
      is_expected.to converge_test_recipe(
        :recipe => 'upload/different_file.rb',
        :expected => 'Different file currently exists on Nexus (or checksums are missing), if you want to overwrite it, set attribute :update_if_exists to true',
        :fail_if => 'uploaded file'
      )
    end
  end
  describe 'Overwrite existing artifact' do
    it do
      is_expected.to converge_test_recipe(
        :recipe => 'upload/different_file_update.rb',
        :expected => "uploaded file '/tmp/chef_nexus_rspec_temp/no_extension' to Nexus at 'http://ebj-pilot-nexus.devlab2k.testnet.rim.net/nexus/content/repositories/ebu-opennebula-images/chef-nexus-rspec-test/sub/artifact/1.0.0/artifact-1.0.0.jar'"
      )
    end
  end
  describe 'Try to upload a file using remote_url which does not pass parsing, should fail' do
    it do
      is_expected.to converge_test_recipe(
        :recipe => 'upload/remote_url_no_parse.rb',
        :expected => 'chef-nexus was unable retrieve enough information to generate a pom',
        :fail_if => 'uploaded file'
      )
    end
  end
  idempotency_helper(
    'Upload a file using remote_url which does not pass parsing, without pom',
    'upload/remote_url_no_parse_no_pom.rb',
    "uploaded file '/tmp/chef_nexus_rspec_temp/no_extension' to Nexus at 'http://ebj-pilot-nexus.devlab2k.testnet.rim.net/nexus/content/repositories/ebu-opennebula-images/chef-nexus-rspec-test/no_parse'"
  )
  idempotency_helper(
    'Upload a file using remote_url which passes parsing',
    'upload/remote_url_parse.rb',
    "uploaded file '/tmp/chef_nexus_rspec_temp/no_extension' to Nexus at 'http://ebj-pilot-nexus.devlab2k.testnet.rim.net/nexus/content/repositories/ebu-opennebula-images/chef-nexus-rspec-test/artifact/1.7/artifact-1.7-classifier.pkg'"
  )
  describe 'Try to upload a different file to one that already exists on Nexus using remote_url, should fail.' do
    it do
      is_expected.to converge_test_recipe(
        :recipe => 'upload/remote_url_different_file.rb',
        :expected => 'Different file currently exists on Nexus (or checksums are missing), if you want to overwrite it, set attribute :update_if_exists to true',
        :fail_if => 'uploaded file'
      )
    end
  end
  describe 'Overwrite existing artifact using remote_url' do
    it do
      is_expected.to converge_test_recipe(
        :recipe => 'upload/remote_url_different_file_update.rb',
        :expected => "uploaded file '/tmp/chef_nexus_rspec_temp/has_extension.test' to Nexus at 'http://ebj-pilot-nexus.devlab2k.testnet.rim.net/nexus/content/repositories/ebu-opennebula-images/chef-nexus-rspec-test/sub/artifact/1.0.0/artifact-1.0.0.jar'"
      )
    end
  end

  ##############
  ## DOWNLOAD ##
  ##############

  describe 'Try to download a file using coordinates without packaging, should fail' do
    it do
      is_expected.to converge_test_recipe(
        :recipe => 'download/coordinates_no_packaging.rb',
        :expected => 'Files require an extension, or specify it with :packaging',
        :fail_if => 'downloaded file'
      )
    end
  end
  describe 'Try to download non-existent file, should fail.' do
    it do
      is_expected.to converge_test_recipe(
        :recipe => 'download/coordinates_doesnt_exist.rb',
        :expected => "No file exists at 'http://ebj-pilot-nexus.devlab2k.testnet.rim.net/nexus/content/repositories/ebu-opennebula-images/chef-nexus-rspec-test/artifact/1.0.0/artifact-1.0.0.gary' or you do not permissions",
        :fail_if => 'downloaded file'
      )
    end
  end
  idempotency_helper(
    'Download file using coordinates',
    'download/coordinates.rb',
    "downloaded file '/tmp/chef_nexus_rspec_temp/downloaded.test' from Nexus at 'http://ebj-pilot-nexus.devlab2k.testnet.rim.net/nexus/content/repositories/ebu-opennebula-images/chef-nexus-rspec-test/artifact/1.0.0/artifact-1.0.0.test'"
  )
  describe 'Try to download different file, should fail' do
    it do
      is_expected.to converge_test_recipe(
        :recipe => 'download/remote_url.rb',
        :expected => 'Different version currently exists locally, if you want to overwrite it, set attribute :update_if_exists to true',
        :fail_if => 'downloaded file'
      )
    end
  end
  idempotency_helper(
    'Download and overwrite file using remote_url',
    'download/remote_url_update.rb',
    "downloaded file '/tmp/chef_nexus_rspec_temp/downloaded.test' from Nexus at 'http://ebj-pilot-nexus.devlab2k.testnet.rim.net/nexus/content/repositories/ebu-opennebula-images/chef-nexus-rspec-test/no_parse'"
  )

  ############
  ## DELETE ##
  ############

  idempotency_helper(
    'Delete an artifact using coordinates',
    'delete/coordinates.rb',
    ''
  )
  idempotency_helper(
    'Delete the test folder on Nexus using remote_url',
    'delete/remote_url.rb',
    ''
  )
end
