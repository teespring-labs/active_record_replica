require 'active_support/concern'
module ActiveRecordSlave
  module Extensions
    extend ActiveSupport::Concern

    ActiveRecordSlave::SELECT_METHODS.each do |select_method|
      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{select_method}(sql, name = nil, *args)
          return super if active_record_slave_read_from_master?
  
          ActiveRecordSlave.read_from_master do
            reader_connection.#{select_method}(sql, "Slave: \#{name || 'SQL'}", *args)
          end
        end
      RUBY
    end

    def reader_connection
      Slave.connection
    end

    def begin_db_transaction
      return if ActiveRecordSlave.skip_transactions?
      return super unless ActiveRecordSlave.block_transactions?

      raise(TransactionAttempted, 'Attempting to begin a transaction during a read-only database connection.')
    end

    def commit_db_transaction
      return if ActiveRecordSlave.skip_transactions?
      return super unless ActiveRecordSlave.block_transactions?

      raise(TransactionAttempted, 'Attempting to commit a transaction during a read-only database connection.')
    end

    def create_savepoint(name = current_savepoint_name(true))
      return if ActiveRecordSlave.skip_transactions?
      return super unless ActiveRecordSlave.block_transactions?

      raise(TransactionAttempted, 'Attempting to create a savepoint during a read-only database connection.')
    end

    def rollback_to_savepoint(name = current_savepoint_name(true))
      return if ActiveRecordSlave.skip_transactions?
      return super unless ActiveRecordSlave.block_transactions?

      raise(TransactionAttempted, 'Attempting to rollback a savepoint during a read-only database connection.')
    end

    def release_savepoint(name = current_savepoint_name(true))
      return if ActiveRecordSlave.skip_transactions?
      return super unless ActiveRecordSlave.block_transactions?

      raise(TransactionAttempted, 'Attempting to release a savepoint during a read-only database connection.')
    end

    # Returns whether to read from the master database
    def active_record_slave_read_from_master?
      # Read from master when forced by thread variable, or
      # in a transaction and not ignoring transactions
      ActiveRecordSlave.read_from_master? ||
        (open_transactions > 0) && !ActiveRecordSlave.ignore_transactions?
    end
  end
end
