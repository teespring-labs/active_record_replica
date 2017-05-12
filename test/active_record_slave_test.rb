require File.join(File.dirname(__FILE__), 'test_helper')
require 'logger'
require 'erb'

l                                 = Logger.new('test.log')
l.level                           = ::Logger::DEBUG
ActiveRecord::Base.logger         = l
ActiveRecord::Base.configurations = YAML::load(ERB.new(IO.read('test/database.yml')).result)

# Define Schema in second database (slave)
# Note: This is not be required when the master database is being replicated to the slave db
ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations['test']['slave'])

# Create table users in database active_record_slave_test
ActiveRecord::Schema.define :version => 0 do
  create_table :users, :force => true do |t|
    t.string :name
    t.string :address
  end
end

# Define Schema in master database
ActiveRecord::Base.establish_connection(:test)

# Create table users in database active_record_slave_test
ActiveRecord::Schema.define :version => 0 do
  create_table :users, :force => true do |t|
    t.string :name
    t.string :address
  end
end

# AR Model
class User < ActiveRecord::Base
end

# Install ActiveRecord slave. Done automatically by railtie in a Rails environment
# Also tell it to use the test environment since Rails.env is not available
ActiveRecordSlave.install!(nil, 'test')

#
# Unit Test for active_record_slave
#
class ActiveRecordSlaveTest < Minitest::Test
  describe 'the active_record_slave gem' do

    before do
      ActiveRecordSlave.ignore_transactions = false

      User.delete_all

      @name    = "Joe Bloggs"
      @address = "Somewhere"
      @user    = User.new(
        :name    => @name,
        :address => @address
      )
    end

    after do
      User.delete_all
    end

    it 'saves to master' do
      assert_equal true, @user.save!
    end

    #
    # NOTE:
    #
    #   There is no automated replication between the SQL lite databases
    #   so the tests will be verifying that reads going to the "slave" (second)
    #   database do not find data written to the master.
    #
    it 'saves to master, read from slave' do
      # Read from slave
      assert_equal 0, User.where(:name => @name, :address => @address).count

      # Write to master
      assert_equal true, @user.save!

      # Read from slave
      assert_equal 0, User.where(:name => @name, :address => @address).count
    end

    it 'save to master, read from master when in a transaction' do
      assert_equal false, ActiveRecordSlave.ignore_transactions?

      User.transaction do
        # The delete_all in setup should have cleared the table
        assert_equal 0, User.count

        # Read from Master
        assert_equal 0, User.where(:name => @name, :address => @address).count

        # Write to master
        assert_equal true, @user.save!

        # Read from Master
        assert_equal 1, User.where(:name => @name, :address => @address).count
      end

      # Read from Non-replicated slave
      assert_equal 0, User.where(:name => @name, :address => @address).count
    end

    it 'save to master, read from slave when ignoring transactions' do
      ActiveRecordSlave.ignore_transactions = true
      assert_equal true, ActiveRecordSlave.ignore_transactions?

      User.transaction do
        # The delete_all in setup should have cleared the table
        assert_equal 0, User.count

        # Read from Master
        assert_equal 0, User.where(:name => @name, :address => @address).count

        # Write to master
        assert_equal true, @user.save!

        # Read from Non-replicated slave
        assert_equal 0, User.where(:name => @name, :address => @address).count
      end

      # Read from Non-replicated slave
      assert_equal 0, User.where(:name => @name, :address => @address).count
    end

    it 'saves to master, force a read from master even when _not_ in a transaction' do
      # Read from slave
      assert_equal 0, User.where(:name => @name, :address => @address).count

      # Write to master
      assert_equal true, @user.save!

      # Read from slave
      assert_equal 0, User.where(:name => @name, :address => @address).count

      # Read from Master
      ActiveRecordSlave.read_from_master do
        assert_equal 1, User.where(:name => @name, :address => @address).count
      end
    end

  end
end
