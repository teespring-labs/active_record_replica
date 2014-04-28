lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

# Maintain your gem's version:
require 'active_record_slave/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = 'active_record_slave'
  spec.version     = ActiveRecordSlave::VERSION
  spec.platform    = Gem::Platform::RUBY
  spec.authors     = ['Reid Morrison']
  spec.email       = ['reidmo@gmail.com']
  spec.homepage    = 'https://github.com/reidmorrison/active_record_slave'
  spec.summary     = "ActiveRecord drop-in solution to efficiently redirect reads to slave databases"
  spec.files       = Dir["lib/**/*", "LICENSE.txt", "Rakefile", "README.md"]
  spec.test_files  = Dir["test/**/*"]
  spec.license     = "Apache License V2.0"
  spec.has_rdoc    = true
  spec.add_dependency 'sync_attr', '>= 1.0'
  spec.add_dependency 'thread_safe', '>= 0.1.0'
end
