# Chef::Nexus

chef-nexus is a Ruby gem that provides the `nexus` Chef resource for managing artifacts on Nexus by Sonatype.

## Usage

Simply install the gem and `require 'chef/nexus'` in your recipes, then you can use the `nexus` resource.

There is an optional Nexus config file that you can create and it will be read in the following order:
1. `File.read(ENV['NEXUS_CONFIG'])`
2. `File.read("#{ENV['HOME']}/.nexus/config")`
3. `File.read('/etc/.nexus/config')`

**NOTE:** only the first one found will be loaded

Example config file:
```json
{
    "default": {
        "url": "http://mynexus.net/nexus/content/",
        "repo": "name_of_repo",
        "auth": "gary:secr3t"
    },
    "gary": {
        "url": "http://mynexus.net/nexus/content/",
        "repo": "disk_images",
        "auth": "gary:p@ssw0rd"
    }
}
```

**NOTE:**

* You can pick different profiles with attribute `nexus_profile`
* You can set you default profile with environment variable `export NEXUS_PROFILE=gary`
* If you don't set the env variable or use the attributes below - `"default"` profile must be present, or you will need to specify the `nexus_profile` attribute every time.
* Attribute `nexus_profile` has precedence over environment variable

You can also specify these as attributes:
```ruby
nexus_url 'http://mynexus.net/nexus/content/'
nexus_repo 'name_of_repo'
nexus_auth 'gary:secr3t'
```

And as environment variables:
```shell
export NEXUS_URL=http://mynexus.net/nexus/content/
export NEXUS_REPO=name_of_repo
export NEXUS_AUTH=gary:secr3t
```

Order of precedence:
1. `attribute`
2. `environment`
3. `config`

### Attributes

```ruby
  :nexus_profile => String of the profile you want to use
  :nexus_url => String url of Nexus
  :nexus_repo => String name of your repository
  :nexus_auth => String of your Nexus credentials
  :use_auth => Boolean specifing whether to authenticate against the Nexus server, fix for 403 Forbidden

  :upload_pom => Boolean indicating whether to generate and upload a pom file, default true
  :update_if_exists => Boolean specifying whether to overwrite existing artifacts during upload action (deletes artifact folder first) 

  :local_file => String absolute path to the file to upload from, or download to
  :remote_url => String of the URL to be upload to / download from, if used, all attributes below are ignored. SEE NOTES

  :coordinates => String Maven coordinates, see: https://maven.apache.org/pom.html#Maven_Coordinates
  :groupId => String name of group
  :artifactId => String name of artifact
  :packaging => String of packaging type
  :classifier => String name of the files classifier
  :version => [String, Fixnum, Float] of the version
```
**NOTE:**

* `:remote_url` will be parsed for pom information if it is syntactically correct according to Maven & Nexus standards, as in:
`<NEXUS_URL>/repositories/<NEXUS_REPO>/<groupId>/<artifactId>/<version>/<artifactId>-<version>-<classifier>.<packaging>`
* `:remote_url` takes precedence over coordinates as the upload / download endpoint.
* Usage of `:remote_url` is **NOT RECOMMENDED**
* Order of precedence during generation of pom file: 
(groupId & artifactId & packaging & classifier & version) > coordinates > remote_url

### Actions

```ruby
  actions :upload, :download, :delete, :delete_url
  default_action :upload
```

### Examples

#### 1. Upload a file to Nexus without authentication and without the pom file

```ruby
nexus 'some description' do
  use_auth false
  upload_pom false
  
  coordinates 'com.gary.image:cloud-img:jar:1.2.0'
  local_file '/home/gary/cloud-img-1.2.0.jar'
  
  action :upload
end
```

#### 2. Upload a file to Nexus without using coordinates and overriding Nexus endpoint config

```ruby
nexus 'some description' do
  local_file '/home/gary/cloud-img-1.2.0.jar'
  
  nexus_url 'http://mynexus.net/nexus/content/repositories/'
  nexus_auth 'gary:secr3t'
  nexus_repo 'name_of_repo'

  groupId 'com.gary.image'
  artifactId 'cloud-img'
  packaging 'jar'
  classifier 'some_classifier'
  version '1.2.0'
  
  action :upload
end
```

#### 3. Upload a file to an exact location on Nexus using remote_url (not recommended)

```ruby
nexus 'some description' do  
  remote_url 'http://mynexus.net/nexus/content/repositories/com/gary/image/cloud-img/some_folder/bad_practice.jar'
  local_file '/home/gary/cloud-img-1.2.0.jar'
  
  action :upload
end
```

#### 4. Download a file from Nexus using coordinates, with another profile

```ruby
nexus 'some description' do
  nexus_profile 'gary'
  coordinates 'com.gary.image:cloud-img:jar:1.2.0'
  local_file '/home/gary/cloud-img-1.2.0.jar'
  
  action :download
end
```

#### 5. Download a file from Nexus using remote_url

```ruby
nexus 'some description' do
  remote_url 'http://mynexus.net/nexus/content/repositories/com/gary/image/cloud-img/1.2.0/cloud-img-1.2.0.jar'
  local_file '/home/gary/cloud-img-1.2.0.jar'
  
  action :download
end
```

#### 6. Delete an artifact from Nexus

```ruby
nexus 'some description' do
  coordinates 'com.gary.image:cloud-img:jar:1.2.0'
  
  action :delete
end
```
**NOTE:** This action does not accept attribute `:remote_url` as it is dangerous to do so. **Ex.** you might delete *ALL* artifacts by accident

**WARNING:** This action will delete the version folder (folder that holds the file), so everything inside it will be deleted as well

#### 7. Delete a file or folder from Nexus (delete folder 1.2.0 in this case)

```ruby
nexus 'some description' do
  remote_url 'http://mynexus.net/nexus/content/repositories/com/gary/image/cloud-img/1.2.0/'
  
  action :delete_url
end
```
**NOTE:** This action requires attribute `:remote_url`

## Development

* Source hosted at [GitHub](https://github.com/blackberry/chef-nexus)
* Report issues/questions/feature requests on [GitHub Issues](https://github.com/blackberry/chef-nexus/issues)

Pull requests are very welcome! Make sure your patches are well tested. Ideally create a topic branch for every separate change you make. For example:

1. Fork the repo
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

To build and install the gem, go to your `chef-nexus` folder and then run:

1. `rake build`
2. `gem install pkg/chef-nexus-x.y.z.gem`, where `x.y.z` is the version you just built

### Testing

Please test your changes! Here's how:

1. Create and configure `spec/config.rb` from `spec/config_sample.rb`
2. Run `rspec spec/chef/nexus_spec.rb` from your `chef-nexus` folder

If you add new functionality, please create new tests accordingly.

## Authors

Created by [Dongyu 'Gary' Zheng](https://github.com/dongyuzheng) (<garydzheng@gmail.com>)

## Maintainers

* [Bogdan Buczynski](https://github.com/bbuczynski) (<pikus1@gmail.com>)
* [Phil Oliva](https://github.com/poliva83) (<philoliva8@gmail.com>)
