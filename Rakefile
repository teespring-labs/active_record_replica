lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'rake/clean'
require 'rake/testtask'
require 'date'
require 'active_record_slave/version'

desc "Build gem"
task :gem  do |t|
  gemspec = Gem::Specification.new do |s|
    s.name        = 'active_record_slave'
    s.version     = ActiveRecordSlave::VERSION
    s.platform    = Gem::Platform::RUBY
    s.authors     = ['Reid Morrison']
    s.email       = ['reidmo@gmail.com']
    s.homepage    = 'https://github.com/ClarityServices/active_record_slave'
    s.date        = Date.today.to_s
    s.summary     = "ActiveRecord read from slave"
    s.description = "ActiveRecordSlave is a library to seamlessly enable reading from database slaves in a Rails 3 project, written in Ruby."
    s.files       = FileList["./**/*"].exclude(/.gem$/, /.log$/,/nbproject/,/sqlite3$/).map{|f| f.sub(/^\.\//, '')}
    s.has_rdoc    = true
    #s.add_dependency 'activerecord', '>= 3.0.0'
  end
  Gem::Builder.new(gemspec).build
end

desc "Run Test Suite"
task :test do
  Rake::TestTask.new(:functional) do |t|
    t.test_files = FileList['test/*_test.rb']
    t.verbose    = true
  end

  Rake::Task['functional'].invoke
end
