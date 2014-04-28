require 'rake/clean'
require 'rake/testtask'

$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require 'active_record_slave/version'

task :gem do
  system "gem build active_record_slave.gemspec"
end

task :publish => :gem do
  system "git tag -a v#{ActiveRecordSlave::VERSION} -m 'Tagging #{ActiveRecordSlave::VERSION}'"
  system "git push --tags"
  system "gem push active_record_slave-#{ActiveRecordSlave::VERSION}.gem"
  system "rm active_record_slave-#{ActiveRecordSlave::VERSION}.gem"
end

desc "Run Test Suite"
task :test do
  Rake::TestTask.new(:functional) do |t|
    t.test_files = FileList['test/*_test.rb']
    t.verbose    = true
  end

  Rake::Task['functional'].invoke
end

task :default => :test
