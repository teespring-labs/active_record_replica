# frozen_string_literal: true

require "active_record"
require "active_record/base"
require "active_record_replica/errors"
require "active_record_replica/replica" unless ActiveRecord::VERSION::MAJOR >= 6
require "active_record_replica/version"
require "active_record_replica/active_record_replica"
require "active_record_replica/extensions"

require "active_record_replica/railtie" if defined?(Rails)
