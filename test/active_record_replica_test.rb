# frozen_string_literal: true

require_relative "test_helper"

#
# Unit Test for active_record_replica
#
# Since there is no database replication in this test environment, it will
# use 2 separate databases. Writes go to the first database and reads to the second.
# As a result any writes to the first database will not be visible when trying to read from
# the second test database.
#
# The tests verify that reads going to the replica database do not find data written to the primary.
class ActiveRecordReplicaTest < Minitest::Test
  describe ActiveRecordReplica do
    let(:user_name) { "Joe Bloggs" }
    let(:address) { "Somewhere" }
    let(:user) { User.new(name: user_name, address: address) }

    before do
      ActiveRecordReplica.ignore_transactions = false
      ActiveRecordReplica.read_from!(:slave)
      User.delete_all
    end

    it "saves to primary" do
      user.save!
    end

    it "saves to primary, read from replica" do
      # Read from replica
      assert_equal 0, User.where(name: user_name, address: address).count

      # Write to primary
      user.save!

      # Read from replica
      assert_equal 0, User.where(name: user_name, address: address).count
    end

    it "save to primary, read from primary when in a transaction" do
      assert_equal false, ActiveRecordReplica.ignore_transactions?

      User.transaction do
        # The delete_all in setup should have cleared the table
        assert_equal 0, User.count

        # Read from Primary
        assert_equal 0, User.where(name: user_name, address: address).count

        # Write to primary
        user.save!

        # Read from Primary
        assert_equal 1, User.where(name: user_name, address: address).count
      end

      # Read from Non-replicated replica
      assert_equal 0, User.where(name: user_name, address: address).count
    end

    it "save to primary, read from replica when ignoring transactions" do
      ActiveRecordReplica.ignore_transactions = true
      assert ActiveRecordReplica.ignore_transactions?

      User.transaction do
        # The delete_all in setup should have cleared the table
        assert_equal 0, User.where(name: user_name, address: address).count

        # Read from Primary
        assert_equal 0, User.where(name: user_name, address: address).count

        # Write to primary
        user.save!

        # Read from Non-replicated replica
        assert_equal 0, User.where(name: user_name, address: address).count
      end

      # Read from Non-replicated replica
      assert_equal 0, User.where(name: user_name, address: address).count
    end

    it "saves to primary, force a read from primary even when _not_ in a transaction" do
      # Read from replica
      assert_equal 0, User.where(name: user_name, address: address).count

      # Write to primary
      user.save!

      # Read from replica
      assert_equal 0, User.where(name: user_name, address: address).count

      # Read from Primary
      ActiveRecordReplica.read_from_primary do
        assert_equal 1, User.where(name: user_name, address: address).count
      end
    end

    it "can switch between different replicas" do
      ActiveRecordReplica.read_from_primary do
        assert_equal 0, User.count
      end
      ActiveRecordReplica.read_from(:slave) do
        assert_equal 'slave', User.first.name
      end
      ActiveRecordReplica.read_from(:slow_slave) do
        assert_equal 'slow slave', User.first.name
      end
    end

    describe ".read_from?" do
      it "is true when global replica flag is set" do
        ActiveRecordReplica.read_from!(:slave)
        assert ActiveRecordReplica.read_from?(:slave)
        refute ActiveRecordReplica.read_from?(:slow_slave)
      end

      it "is true when global replica flag is set" do
        ActiveRecordReplica.read_from!(:slow_slave)
        assert ActiveRecordReplica.read_from?(:slow_slave)
        refute ActiveRecordReplica.read_from?(:slave)
      end

      it "is false when reading from replica" do
        ActiveRecordReplica.read_from_primary!
        refute ActiveRecordReplica.read_from?(:slave)
        refute ActiveRecordReplica.read_from?(:slow_slave)
      end
    end

    describe ".read_from_primary?" do
      it "is true when global primary flag is set" do
        ActiveRecordReplica.read_from_primary!
        assert ActiveRecordReplica.read_from_primary?
      end

      it "is false when reading from replica" do
        ActiveRecordReplica.read_from!(:slave)
        refute ActiveRecordReplica.read_from_primary?
      end
    end

    describe ".read_from" do
      it "works with global replica flag" do
        ActiveRecordReplica.read_from!(:slave)
        ActiveRecordReplica.read_from(:slave) do
          assert ActiveRecordReplica.read_from?(:slave)
          refute ActiveRecordReplica.read_from?(:slow_slave)
          refute ActiveRecordReplica.read_from_primary?
        end
      end

      it "overwrites global replica flag" do
        ActiveRecordReplica.read_from_primary!
        ActiveRecordReplica.read_from(:slave) do
          assert ActiveRecordReplica.read_from?(:slave)
          refute ActiveRecordReplica.read_from?(:slow_slave)
          refute ActiveRecordReplica.read_from_primary?
        end
      end

      it "overwrites global replica flag" do
        ActiveRecordReplica.read_from_primary!
        ActiveRecordReplica.read_from(:slow_slave) do
          assert ActiveRecordReplica.read_from?(:slow_slave)
          refute ActiveRecordReplica.read_from?(:slave)
          refute ActiveRecordReplica.read_from_primary?
        end
      end
    end

    describe ".read_from_primary" do
      it "works with global replica flag" do
        ActiveRecordReplica.read_from_primary!
        ActiveRecordReplica.read_from_primary do
          assert ActiveRecordReplica.read_from_primary?
          refute ActiveRecordReplica.read_from?(:slave)
          refute ActiveRecordReplica.read_from?(:slow_slave)
        end
      end

      it "overwrites global replica flag" do
        ActiveRecordReplica.read_from!(:slave)
        ActiveRecordReplica.read_from_primary do
          assert ActiveRecordReplica.read_from_primary?
          refute ActiveRecordReplica.read_from?(:slave)
          refute ActiveRecordReplica.read_from?(:slow_slave)
        end
      end
    end
  end
end
