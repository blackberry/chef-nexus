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

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'chef/nexus'
require_relative 'config.rb'

def chef_run(recipe, append_path = true)
  `chef-client -z #{append_path ? './spec/chef/recipes/' + recipe : recipe} --force-formatter`
end

def format_error(msg)
  "================================================================================\n#{msg}\n================================================================================\n "
end

def get_unique_file(path, basename, rest)
  p = path.chomp('/')
  fn = "#{p}/#{basename}#{rest}"
  return fn unless File.exist?(fn)
  n = 1
  n += 1 while File.exist?("#{p}/#{basename}__#{n}#{rest}")
  "#{p}/#{basename}__#{n}#{rest}"
end

def get_error(stdout, expected, fail_if)
  stacktrace = stdout.match(/FATAL: Stacktrace dumped to (.*?chef-stacktrace\.out)/)
  stacktrace = stacktrace ? stacktrace[1] : nil
  err = stacktrace ? "Chef run did not report 'Chef Client finished'." : nil

  case fail_if
    when Regexp
      return "stdout matched the following when it should not have:\n#{fail_if}", stacktrace if stdout =~ fail_if
    when String
      return "stdout included the following when it should not have:\n#{fail_if}", stacktrace if stdout.include?(fail_if)
  end unless fail_if.nil?

  # Each chef run can only fail due to one reason, so if it was an expected error, we can simply return nil
  [' RuntimeError: ', ' NoMethodError: ', ' TypeError: ', ' ERROR: ', ' FATAL: '].each do |e|
    the_error = (stdout.split(e).last).split("\n")[0...-1].join("\n")
    case expected
      when Regexp
        if e + the_error =~ expected
          return nil, nil
        else
          return "#{e.strip}\n#{the_error}", stacktrace
        end
      when String
        if (e + the_error).include?(expected)
          return nil, nil
        else
          return "#{e.strip}\n#{the_error}", stacktrace
        end
      else
        return "#{e.strip}\n#{the_error}", stacktrace
    end if stdout.include?(e)
  end if err

  return err, stacktrace if expected.nil?

  case expected
    when Regexp
      return "stdout did not match the following when it should have:\n#{expected}", stacktrace unless stdout =~ expected
    when String
      return "stdout did not include the following when it should have:\n#{expected}", stacktrace unless stdout.include?(expected)
  end

  [err, stacktrace]
end

# data = {
#   :recipe => 'recipe to test, must be given',
#   :expected => 'fail if not match, can be errors',
#   :fail_if => 'fail if match'
# }
RSpec::Matchers.define :converge_test_recipe do |data = {}|
  fail 'All tests require a :recipe.' unless data[:recipe]
  match do
    stdout = chef_run(data[:recipe])
    puts stdout

    dir = RSpec.configuration.log_dir + '/' + File.dirname(data[:recipe])
    FileUtils.mkdir_p(dir)

    log_basename = File.basename(data[:recipe], '.*')
    File.open(get_unique_file("./#{dir}", log_basename, '.stdout.log'), 'w+') { |file| file.write(stdout) }

    @error_message, stacktrace = get_error(stdout, data[:expected], data[:fail_if])
    @error_message = format_error(@error_message) unless @error_message.nil?

    FileUtils.cp(stacktrace, get_unique_file("./#{dir}", log_basename, '.stacktrace.out')) if stacktrace

    @error_message.nil?
  end
  failure_message do
    @error_message
  end
end

def idempotency_helper(context, recipe, expected = nil)
  describe context do
    it { is_expected.to converge_test_recipe(:recipe => recipe, :expected => expected, :fail_if => '(up to date)') }
  end
  describe "[SKIP] #{context}" do
    it { is_expected.to converge_test_recipe(:recipe => recipe, :expected => '(up to date)', :fail_if => nil) }
  end
end

def delete(remote)
  if url_exists(remote)
    execute_or_fail("curl -v #{USE_AUTH ? "-u #{NEXUS_AUTH} " : nil}-X DELETE #{remote}")
    fail "Server responded with successful deletion, but '#{remote}' still exists." if url_exists(remote)
  end
end

def url_exists(url)
  `curl --output /dev/null --silent --head --fail #{USE_AUTH ? "-u #{NEXUS_AUTH} " : nil}#{url}`
  $?.exitstatus == 0
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

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.add_setting :log_dir, :default => "test-results/#{Time.now.strftime('%Y%m%d_%H%M%S')}"
  config.before(:suite) do
    FileUtils.rm_rf(config.log_dir)
    FileUtils.mkdir_p(config.log_dir)
    FileUtils.rm_rf('/tmp/chef_nexus_rspec_temp/')
    FileUtils.mkdir_p('/tmp/chef_nexus_rspec_temp/')
    `echo 'all your base are belong to us' > '/tmp/chef_nexus_rspec_temp/has_extension.test'`
    `echo 'its a trap!' > '/tmp/chef_nexus_rspec_temp/no_extension'`
    delete("#{NEXUS_URL.chomp('/')}/repositories/#{NEXUS_REPO}/chef-nexus-rspec-test/")
  end
  config.after(:suite) do
    FileUtils.rm_rf('/tmp/chef_nexus_rspec_temp/')
    delete("#{NEXUS_URL.chomp('/')}/repositories/#{NEXUS_REPO}/chef-nexus-rspec-test/")
  end
end
