require 'active_record'
require 'active_record/base'
require 'active_record_slave/version'
require 'active_record_slave/errors'
require 'active_record_slave/slave'
require 'active_record_slave/active_record_slave'
require 'active_record_slave/extensions'

if defined?(Rails)
  require 'active_record_slave/railtie'
end
