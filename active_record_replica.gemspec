$:.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'active_record_replica/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name                  = 'active_record_replica'
  spec.version               = ActiveRecordReplica::VERSION
  spec.platform              = Gem::Platform::RUBY
  spec.authors               = ['Reid Morrison', 'James Brady']
  spec.email                 = ['reidmo@gmail.com', 'james@spri.ng']
  spec.homepage              = 'https://github.com/teespring/active_record_replica'
  spec.summary               = 'Redirect ActiveRecord (Rails) reads to replica databases while ensuring all writes go to the primary database.'
  spec.files                 = Dir['lib/**/*', 'LICENSE.txt', 'Rakefile', 'README.md']
  spec.test_files            = Dir['test/**/*']
  spec.license               = 'Apache-2.0'
  spec.required_ruby_version = '>= 2.0'
  spec.add_dependency 'activerecord', '>= 3.0', '< 6.0.0'
end
