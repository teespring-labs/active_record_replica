ENV['RAILS_ENV'] = 'test'

require 'active_record'
require 'minitest/autorun'
require 'active_record_replica'
require 'awesome_print'
require 'logger'
require 'erb'

l                                 = Logger.new('test.log')
l.level                           = ::Logger::DEBUG
ActiveRecord::Base.logger         = l
ActiveRecord::Base.configurations = YAML::load(ERB.new(IO.read('test/database.yml')).result)

def create_schema
  # Create table users in database active_record_replica_test
  ActiveRecord::Schema.define :version => 0 do
    create_table :users, :force => true do |t|
      t.string :name
      t.string :address
    end
  end
end

# AR Model
class User < ActiveRecord::Base
end

# Define Schema in second database (replica)
# Note: This is not be required when the primary database is being replicated to the replica db
ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations['test'].symbolize_keys[:slave])
create_schema
User.create!(name: 'slave')

ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations['test'].symbolize_keys[:slow_slave])
create_schema
User.create!(name: 'slow slave')

# Define Schema in primary database
ActiveRecord::Base.establish_connection(:test)
create_schema

# Install ActiveRecord replica. Done automatically by railtie in a Rails environment
# Also tell it to use the test environment since Rails.env is not available
ActiveRecordReplica.install!(nil, 'test', [:slave, :slow_slave], default: :slave)
