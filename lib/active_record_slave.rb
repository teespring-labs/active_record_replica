require 'active_record'
require 'active_record/base'
require 'active_record_slave/version'
require 'active_record_slave/slave'
require 'active_record_slave/instance_methods'
require 'active_record_slave/active_record_slave'

if defined?(Rails)
  require 'active_record_slave/railtie'
end
