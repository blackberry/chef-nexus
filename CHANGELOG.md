# Changelog

## 0.2.0 (09/13/2016)
- Remove dependency on compat-resource as a gem (resolves https://github.com/blackberry/chef-nexus/issues/6)

## 0.1.2 (04/28/2016)
- Added copyright notices
- Created .rubocop.yml and ran RuboCop

## 0.1.1 (04/04/2016)
- Fixed bug regarding improper parsing of local_file with names like test.0.0.4.qcow2
- Now guarding against empty strings for coordinates

## 0.1.0 (03/23/2016)
- Implemented actions :upload, :download, :delete, :delete_url
- Created rspec tests
