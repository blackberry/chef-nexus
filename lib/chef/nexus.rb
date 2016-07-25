# Copyright 2016, BlackBerry, Inc.
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

require 'chef_compat/resource'
require 'active_support/all'
require 'json'
require 'erb'
require 'digest'

class Chef
  class Resource
    #
    # Chef resource for managing artifacts on Nexus by Sonatype
    #
    class Nexus < ChefCompat::Resource
      resource_name :nexus

      property :nexus_profile, String, desired_state: false
      property :nexus_url, String, desired_state: false
      property :nexus_repo, String, desired_state: false
      property :nexus_auth, String, desired_state: false
      property :use_auth, [TrueClass, FalseClass], default: true, desired_state: false

      property :upload_pom, [TrueClass, FalseClass], default: true, desired_state: false
      property :update_if_exists, [TrueClass, FalseClass], default: false

      property :local_file, String, desired_state: false
      property :remote_url, String, desired_state: false

      property :coordinates, String, desired_state: false
      property :groupId, String, desired_state: false
      property :artifactId, String, desired_state: false
      property :packaging, String, desired_state: false
      property :classifier, String, desired_state: false
      property :version, [String, Fixnum, Float], desired_state: false

      property :file_sha1, [String, NilClass]
      property :file_md5, [String, NilClass]
      property :pom_sha1, [String, NilClass]
      property :pom_md5, [String, NilClass]

      load_current_value do
        file_sha1 download_and_read(curl_url + '.sha1')
        file_md5 download_and_read(curl_url + '.md5')
        if upload_pom && can_generate_pom
          pom_sha1 download_and_read(curl_base_url + '.pom.sha1')
          pom_md5 download_and_read(curl_base_url + '.pom.md5')
        end
      end

      action :upload do
        fail ':local_file is missing' unless local_file
        fail "#{local_file} does not exist" unless ::File.exist?(local_file)

        if upload_pom && !can_generate_pom
          msg = "chef-nexus was unable retrieve enough information to generate a pom\n"
          msg << "is :remote_url correct in terms of Maven & Nexus syntax? See README: Attributes - Notes\n"
          msg << 'Set attribute :upload_pom false to bypass this error.'
          fail msg
        end

        file_sha1 local_file_sha1
        file_md5 local_file_md5

        unless file_equal(current_resource)
          if file_exists
            fail 'Different file currently exists on Nexus (or checksums are missing), if you want to overwrite it, set attribute :update_if_exists to true' unless update_if_exists
            delete(curl_url)
          end
          converge_by "uploaded file '#{local_file}' to Nexus at '#{curl_url}'" do
            upload(local_file, curl_url)
          end
        end

        converge_if_changed :file_sha1 do
          delete(curl_url + '.sha1') if url_exists(curl_url + '.sha1')
          write_file(curl_url + '.sha1', file_sha1)
        end

        converge_if_changed :file_md5 do
          delete(curl_url + '.md5') if url_exists(curl_url + '.md5')
          write_file(curl_url + '.md5', file_md5)
        end

        if upload_pom
          pom_content = ERB.new(::File.read("#{::File.dirname(__FILE__)}/pom.erb"), nil, '-').result(binding)

          pom_sha1 Digest::SHA1.hexdigest(pom_content)
          pom_md5 Digest::MD5.hexdigest(pom_content)

          unless pom_equal(current_resource)
            if pom_exists
              fail 'Different pom currently exists on Nexus (or checksums are missing), if you want to overwrite it, set attribute :update_if_exists to true' unless update_if_exists
              delete(curl_base_url + '.pom')
            end
            converge_by "uploaded pom to Nexus at '#{curl_base_url + '.pom'}'" do
              write_file(curl_base_url + '.pom', pom_content)
            end
          end

          converge_if_changed :pom_sha1 do
            delete(curl_base_url + '.pom.sha1') if url_exists(curl_base_url + '.pom.sha1')
            write_file(curl_base_url + '.pom.sha1', pom_sha1)
          end

          converge_if_changed :pom_md5 do
            delete(curl_base_url + '.pom.md5') if url_exists(curl_base_url + '.pom.md5')
            write_file(curl_base_url + '.pom.md5', pom_md5)
          end
        end
      end

      action :download do
        fail ':local_file is missing' unless local_file
        fail "No file exists at '#{curl_url}' or you do not permissions" unless file_exists
        unless file_equal(current_resource)
          fail 'Different version currently exists locally, if you want to overwrite it, set attribute :update_if_exists to true' if ::File.exist?(local_file) && !update_if_exists
          converge_by "downloaded file '#{local_file}' from Nexus at '#{curl_url}'" do
            execute_or_fail("mkdir -p #{::File.dirname(local_file)}")
            download(curl_url, local_file)
            updated_by_last_action(true)
          end
        end
      end

      action :delete do
        fail 'action :delete does not accept attribute :remote_url ... use Maven coordinates instead, or use action :delete_url' if remote_url
        converge_by "deleted artifact '#{curl_url}' from Nexus" do
          delete(curl_url.split('/')[0...-1].join('/'))
          updated_by_last_action(true)
        end if url_exists(curl_url.split('/')[0...-1].join('/'))
      end

      action :delete_url do
        fail 'action :delete_url requires attribute :remote_url' unless remote_url
        converge_by "deleted '#{curl_url}' from Nexus" do
          delete(curl_url)
          updated_by_last_action(true)
        end if url_exists(curl_url)
      end

      protected

      def upload(local, remote)
        execute_or_fail("curl -v #{use_auth ? "-u #{n_auth} " : nil}-T #{local} #{remote}")
        fail "Server responded with successful creation, but '#{remote}' does not exist." unless url_exists(remote)
      end

      def download(remote, local)
        execute_or_fail("curl -v #{use_auth ? "-u #{n_auth} " : nil}#{remote} > #{local}")
        fail "File appears to have been downloaded, but '#{local}' does not exist." unless ::File.exist?(local)
      end

      def delete(remote)
        execute_or_fail("curl -v #{use_auth ? "-u #{n_auth} " : nil}-X DELETE #{remote}")
        fail "Server responded with successful deletion, but '#{remote}' still exists." if url_exists(remote)
      end

      def execute_or_fail(cmd, check_http = true)
        output = `#{cmd}`
        fail_me = false
        output.scan(%r{^ +<title>(\d{3}) - .*?</title>$}).each { |code| fail_me = true unless code[0] == '1' || code[0] == '2' } if check_http
        if $?.exitstatus != 0 || fail_me
          fail "Command failed: #{cmd}\n<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n#{output.strip}\n>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n"
        end
        output
      end

      def write_file(remote, content)
        tmp = '/tmp/' + Digest::SHA1.hexdigest(rand(100000000000000).to_s)
        ::File.open(tmp, 'w') { |file| file.write(content) }
        upload(tmp, remote)
        ::File.delete(tmp)
      end

      def cords
        @cords ||= begin
          hsh = {}
          if remote_url
            scn = remote_url.scan(%r{^.*?/repositories/.*?/(.*?)/((?:\d+\.)*\d+)/(.*?)-((?:\d+\.)*\d+)(?:-(.*?))?\.(.*)$})
            if scn.length == 1 && scn[0][1] == scn[0][3]
              group_id, _, artifact_id = scn[0][0].rpartition('/')
              if !group_id.empty? && artifact_id == scn[0][2]
                hsh[:groupId] = group_id.tr('/', '.')
                hsh[:artifactId] = artifact_id
                hsh[:version] = scn[0][1]
                hsh[:packaging] = scn[0][5]
                hsh[:classifier] = scn[0][4]
              end
            end
            hsh.delete_if { |_, v| v.nil? }
          end
          if coordinates
            splt = coordinates.split(':')
            unless splt.length >= 3 && splt.length <= 5
              fail %q(:coordinates must follow the one of the following formats
groupId:artifactId:version
groupId:artifactId:packaging:version
groupId:artifactId:packaging:classifier:version)
            end
            hsh[:groupId] = splt.first
            hsh[:artifactId] = splt[1]
            hsh[:version] = splt.last
            hsh[:packaging] = splt[2] if splt.length >= 4
            hsh[:classifier] = splt[3] if splt.length == 5
          end
          %w(groupId artifactId version packaging classifier).each do |x|
            p = eval(x)
            hsh[x.to_sym] = p if p
          end

          [:groupId, :artifactId, :version].each do |x|
            fail 'Your must specify :coordinates OR at least all of [:groupId, :artifactId, :version]' unless hsh[x].present?
          end unless remote_url

          if local_file && !hsh[:packaging].present?
            extn = ::File.extname(local_file)
            if !remote_url && extn.empty?
              fail 'Files require an extension, or specify it with :packaging'
            else
              hsh[:packaging] = extn[1..-1]
            end
          end
          hsh
        end
      end

      def curl_url
        @curl_url ||= begin
          remote_url || begin
            url = curl_base_url.dup
            url += "-#{cords[:classifier]}" if cords[:classifier]
            url += ".#{cords[:packaging]}"
            url
          end
        end
      end

      def curl_base_url
        @curl_base_url ||= begin
          url = [n_url, 'repositories', n_repo]
          url.push(cords[:groupId].split('.')).flatten!
          url.push(cords[:artifactId])
          url.push(cords[:version])
          url.push("#{cords[:artifactId]}-#{cords[:version]}")
          url.join('/')
        end
      end

      def n_url
        @n_url ||= begin
          nurl = nexus_url || ENV['NEXUS_URL'] || n_config['url']
          fail "Please provide Nexus url as either an attribute :nexus_url or in ~/.nexus/config profile '#{n_profile}'" unless nurl
          nurl.chomp('/')
        end
      end

      def n_auth
        @n_auth ||= begin
          nauth = nexus_auth || ENV['NEXUS_AUTH'] || n_config['auth']
          fail "Please provide Nexus auth as either an attribute :nexus_auth or in ~/.nexus/config profile '#{n_profile}'" if use_auth && !nauth
          nauth
        end
      end

      def n_repo
        @n_repo ||= begin
          nrepo = nexus_repo || ENV['NEXUS_REPO'] || n_config['repo']
          fail "Please provide Nexus repository as either an attribute :repository or in ~/.nexus/config profile '#{n_profile}'" unless nrepo
          nrepo
        end
      end

      def n_config
        @n_config ||= begin
          if ENV['NEXUS_CONFIG'] && ::File.exist?(ENV['NEXUS_CONFIG'])
            JSON.parse(::File.read(ENV['NEXUS_CONFIG']))[n_profile] || {}
          elsif ::File.exist?("#{ENV['HOME']}/.nexus/config")
            JSON.parse(::File.read("#{ENV['HOME']}/.nexus/config"))[n_profile] || {}
          elsif ::File.exist?('/etc/.nexus/config')
            JSON.parse(::File.read('/etc/.nexus/config'))[n_profile] || {}
          else
            {}
          end
        end
      end

      def n_profile
        @n_profile ||= nexus_profile || ENV['NEXUS_PROFILE'] || 'default'
      end

      def local_file_md5
        @local_file_md5 ||= begin
          ::File.open(local_file, 'rb') do |f|
            digest = Digest::MD5.new
            buffer = ''
            digest.update(buffer) while f.read(4096, buffer)
            digest.hexdigest
          end if ::File.exist?(local_file)
        end
      end

      def local_file_sha1
        @local_file_sha1 ||= begin
          ::File.open(local_file, 'rb') do |f|
            digest = Digest::SHA1.new
            buffer = ''
            digest.update(buffer) while f.read(4096, buffer)
            digest.hexdigest
          end if ::File.exist?(local_file)
        end
      end

      def file_exists
        @file_exists ||= url_exists(curl_url)
      end

      # If neither SHA1 or MD5 checksums are on Nexus, we will assume not equal.
      def file_equal(current_resource)
        @file_equal ||= begin
          if file_exists
            return true if current_resource.file_sha1 && local_file_sha1 == current_resource.file_sha1
            return true if current_resource.file_md5 && local_file_md5 == current_resource.file_md5
          end
          false
        end
      end

      def pom_exists
        @pom_exists ||= url_exists(curl_base_url + '.pom')
      end

      def pom_equal(current_resource)
        @pom_equal ||= begin
          if pom_exists
            return true if current_resource.pom_sha1 && pom_sha1 == current_resource.pom_sha1
            return true if current_resource.pom_md5 && pom_md5 == current_resource.pom_md5
          end
          false
        end
      end

      def can_generate_pom
        @can_generate_pom ||= [:groupId, :artifactId, :version, :packaging].all? { |x| cords.key?(x) }
      end

      def url_exists(url)
        `curl --output /dev/null --silent --head --fail #{use_auth ? "-u #{n_auth} " : nil}#{url}`
        $?.exitstatus == 0
      end

      def download_and_read(url)
        return nil unless url_exists(url)
        tmp = '/tmp/' + Digest::SHA1.hexdigest(rand(100000000000000).to_s)
        cmd = "curl -v #{use_auth ? "-u #{n_auth} " : nil}#{url} > #{tmp}"
        execute_or_fail(cmd)
        content = ::File.read(tmp)
        ::File.delete(tmp)
        content
      end
    end
  end
end
