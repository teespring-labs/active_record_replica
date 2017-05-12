ENV['RAILS_ENV'] = 'test'

require 'active_record'
require 'minitest/autorun'
require 'minitest/reporters'
require 'minitest/stub_any_instance'
require 'active_record_slave'
require 'awesome_print'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new
