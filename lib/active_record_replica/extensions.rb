# frozen_string_literal: true

require "active_support/concern"
module ActiveRecordReplica
  module Extensions
    extend ActiveSupport::Concern

    %i[select select_all select_one select_rows select_value select_values].each do |select_method|
      class_eval <<~RUBY, __FILE__, __LINE__ + 1
        def #{select_method}(sql, name = nil, *args)
          return super if active_record_replica_read_from_primary?

          active_record_replica_select(:#{select_method}, sql, name, *args)
        end
      RUBY
    end

    if ActiveRecord::VERSION::MAJOR >= 6
      def active_record_replica_select(select_method, sql, name = nil, *args)
        ActiveRecordReplica.read_from_primary do
          if ActiveRecord::Base.current_role == ActiveRecord::Base.reading_role
            public_send(select_method, sql, "Replica: #{name || 'SQL'}", *args)
          else
            ActiveRecord::Base.connected_to(role: ActiveRecord::Base.reading_role) do
              ActiveRecord::Base.connection.public_send(select_method, sql, "Replica: #{name || 'SQL'}", *args)
            end
          end
        end
      end
    else
      def active_record_replica_select(select_method, sql, name = nil, *args)
        ActiveRecordReplica.read_from_primary do
          reader_connection.public_send(select_method, sql, "Replica: \#{name || 'SQL'}", *args)
        end
      end

      def reader_connection
        Replica.connection
      end
    end

    def begin_db_transaction
      return if ActiveRecordReplica.skip_transactions?
      return super unless ActiveRecordReplica.block_transactions?

      raise(TransactionAttempted, "Attempting to begin a transaction during a read-only database connection.")
    end

    def commit_db_transaction
      return if ActiveRecordReplica.skip_transactions?
      return super unless ActiveRecordReplica.block_transactions?

      raise(TransactionAttempted, "Attempting to commit a transaction during a read-only database connection.")
    end

    def create_savepoint(name = current_savepoint_name(true))
      return if ActiveRecordReplica.skip_transactions?
      return super unless ActiveRecordReplica.block_transactions?

      raise(TransactionAttempted, "Attempting to create a savepoint during a read-only database connection.")
    end

    def rollback_to_savepoint(name = current_savepoint_name(true))
      return if ActiveRecordReplica.skip_transactions?
      return super unless ActiveRecordReplica.block_transactions?

      raise(TransactionAttempted, "Attempting to rollback a savepoint during a read-only database connection.")
    end

    def release_savepoint(name = current_savepoint_name(true))
      return if ActiveRecordReplica.skip_transactions?
      return super unless ActiveRecordReplica.block_transactions?

      raise(TransactionAttempted, "Attempting to release a savepoint during a read-only database connection.")
    end

    # Returns whether to read from the primary database
    def active_record_replica_read_from_primary?
      ActiveRecordReplica.read_from_primary? ||
        open_transactions.positive? && !ActiveRecordReplica.ignore_transactions?
    end
  end
end
