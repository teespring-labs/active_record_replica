# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"

require "active_record"
require "minitest/autorun"
require "active_record_replica"
require "amazing_print"
require "logger"
require "erb"

config_file_name = ActiveRecord::VERSION::MAJOR >= 6 ? "test/database_rails6.yml" : "test/database.yml"

l                                 = Logger.new("test.log")
l.level                           = ::Logger::DEBUG
ActiveRecord::Base.logger         = l
ActiveRecord::Base.configurations = YAML.load(ERB.new(IO.read(config_file_name)).result)

# Define Schema in second database (replica)
# Note: This is not be required when the primary database is being replicated to the replica db
ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations["test"]["replica"])

# Create table users in database active_record_replica_test
ActiveRecord::Schema.define version: 0 do
  create_table :users, force: true do |t|
    t.string :name
    t.string :address
  end
end

# Define Schema in primary database
ActiveRecord::Base.establish_connection(:test)

# Create table users in database active_record_replica_test
ActiveRecord::Schema.define version: 0 do
  create_table :users, force: true do |t|
    t.string :name
    t.string :address
  end
end

# AR Model
class User < ActiveRecord::Base
end

# Install ActiveRecord replica. Done automatically by railtie in a Rails environment
# Also tell it to use the test environment since Rails.env is not available
ActiveRecordReplica.install!(environment: "test")
