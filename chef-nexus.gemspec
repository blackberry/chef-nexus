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

# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'chef/nexus/version'

Gem::Specification.new do |spec|
  spec.name = 'chef-nexus'
  spec.version = Chef::Nexus::VERSION
  spec.license = 'Apache 2.0'
  spec.platform = Gem::Platform::RUBY
  spec.extra_rdoc_files = ['README.md', 'LICENSE']

  spec.authors = ['Dongyu \'Gary\' Zheng']
  spec.email = ['garydzheng@gmail.com']

  spec.summary = 'chef-nexus is a Ruby gem that provides the `nexus` Chef resource for managing artifacts on Nexus by Sonatype.'
  spec.description = spec.summary
  spec.homepage = 'https://github.com/blackberry/chef-nexus'

  spec.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'chef'
  spec.add_dependency 'compat_resource', '~> 12.8.0'
  spec.add_dependency 'activesupport'

  spec.add_development_dependency 'bundler', '~> 1.11'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
end
