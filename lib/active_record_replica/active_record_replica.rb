#
# ActiveRecord read from a replica
#
module ActiveRecordReplica
  # Select Methods
  SELECT_METHODS = [:select, :select_all, :select_one, :select_rows, :select_value, :select_values]

  # In case in the future we are forced to intercept connection#execute if the
  # above select methods are not sufficient
  #   SQL_READS = /\A\s*(SELECT|WITH|SHOW|CALL|EXPLAIN|DESCRIBE)/i

  # Install ActiveRecord::Replica into ActiveRecord to redirect reads to the replica
  # Parameters:
  #   adapter_class:
  #     By default, only the default Database adapter (ActiveRecord::Base.connection.class)
  #     is extended with replica read capabilities
  #
  #   environment:
  #     In a non-Rails environment, supply the environment such as
  #     'development', 'production'
  def self.install!(adapter_class = nil, environment = nil)
    replica_config =
      if ActiveRecord::Base.connection.respond_to?(:config)
        ActiveRecord::Base.connection.config[:replica]
      else
        ActiveRecord::Base.configurations[environment || Rails.env]['replica']
      end
    if replica_config
      ActiveRecord::Base.logger.info "ActiveRecordReplica.install! v#{ActiveRecordReplica::VERSION} Establishing connection to replica database"
      Replica.establish_connection(replica_config)

      # Inject a new #select method into the ActiveRecord Database adapter
      base = adapter_class || ActiveRecord::Base.connection.class
      base.include(Extensions)
    else
      ActiveRecord::Base.logger.info "ActiveRecordReplica not installed since no replica database defined"
    end
  end

  # Force reads for the supplied block to read from the primary database
  # Only applies to calls made within the current thread
  def self.read_from_primary
    return yield if read_from_primary?
    begin
      previous = Thread.current.thread_variable_get(:active_record_replica)
      read_from_primary!
      yield
    ensure
      Thread.current.thread_variable_set(:active_record_replica, previous)
    end
  end

  #
  # The default behavior can also set to read/write operations against primary
  # Create an initializer file config/initializer/active_record_replica.rb
  # and set ActiveRecordReplica.read_from_primary! to force read from primary.
  # Then use this method and supply block to read from the replica database
  # Only applies to calls made within the current thread
  def self.read_from_replica
    return yield if read_from_replica?
    begin
      previous = Thread.current.thread_variable_get(:active_record_replica)
      read_from_replica!
      yield
    ensure
      Thread.current.thread_variable_set(:active_record_replica, previous)
    end
  end

  # When only reading from a replica it is important to prevent entering any into
  # a transaction since the transaction still sends traffic to the primary
  # that will cause the primary database to slow down processing empty transactions.
  def self.block_transactions
    begin
      previous = Thread.current.thread_variable_get(:active_record_replica_transaction)
      Thread.current.thread_variable_set(:active_record_replica_transaction, :block)
      yield
    ensure
      Thread.current.thread_variable_set(:active_record_replica_transaction, previous)
    end
  end

  # During this block any attempts to start or end transactions will be ignored.
  # This extreme action should only be taken when 100% certain no writes are going to be
  # performed.
  def self.skip_transactions
    begin
      previous = Thread.current.thread_variable_get(:active_record_replica_transaction)
      Thread.current.thread_variable_set(:active_record_replica_transaction, :skip)
      yield
    ensure
      Thread.current.thread_variable_set(:active_record_replica_transaction, previous)
    end
  end

  # Whether this thread is currently forcing all reads to go against the primary database
  def self.read_from_primary?
    Thread.current.thread_variable_get(:active_record_replica) == :primary
  end

  # Whether this thread is currently forcing all reads to go against the replica database
  def self.read_from_replica?
    Thread.current.thread_variable_get(:active_record_replica).nil?
  end

  # Force all subsequent reads on this thread and any fibers called by this thread to go the primary
  def self.read_from_primary!
    Thread.current.thread_variable_set(:active_record_replica, :primary)
  end

  # Subsequent reads on this thread and any fibers called by this thread can go to a replica
  def self.read_from_replica!
    Thread.current.thread_variable_set(:active_record_replica, nil)
  end

  # Whether any attempt to start a transaction should result in an exception
  def self.block_transactions?
    Thread.current.thread_variable_get(:active_record_replica_transaction) == :block
  end

  # Whether any attempt to start a transaction should be skipped.
  def self.skip_transactions?
    Thread.current.thread_variable_get(:active_record_replica_transaction) == :skip
  end

  # Returns whether replica reads are ignoring transactions
  def self.ignore_transactions?
    @ignore_transactions
  end

  # Set whether replica reads should ignore transactions
  def self.ignore_transactions=(ignore_transactions)
    @ignore_transactions = ignore_transactions
  end

  private

  @ignore_transactions = false
end
