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

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  if ActiveRecord::VERSION::MAJOR >= 6
    connects_to database: { writing: :primary, reading: :primary_reader }
  end
end

# Active Record based model
class User < ApplicationRecord
end

# Create table users in database active_record_replica_test
def create_schema
  ActiveRecord::Schema.define version: 0 do
    create_table :users, force: true do |t|
      t.string :name
      t.string :address
    end
  end
end

# Define Schema in both databases.
# Note: This is for testing purposes only and not needed by a Rails app.
if ActiveRecord::VERSION::MAJOR >= 6
  ApplicationRecord.connected_to(database: :primary_reader) do
    create_schema
  end
  ApplicationRecord.connected_to(database: :primary) do
    create_schema
  end
  ApplicationRecord.establish_connection(:test)
else
  ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations["test"]["replica"])
  create_schema

  # Define Schema in primary database
  ActiveRecord::Base.establish_connection(:test)
  create_schema
end

# Install ActiveRecord replica. Done automatically by railtie in a Rails environment
# Also tell it to use the test environment since Rails.env is not available
ActiveRecordReplica.install!(environment: "test")
