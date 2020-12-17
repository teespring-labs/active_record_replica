# frozen_string_literal: true

#
# ActiveRecord read from a replica
#
module ActiveRecordReplica
  # Install ActiveRecord::Replica into ActiveRecord to redirect reads to the replica
  # Parameters:
  #   adapter_class:
  #     By default, only the default Database adapter (ActiveRecord::Base.connection.class)
  #     is extended with replica read capabilities
  #
  #   environment:
  #     In a non-Rails environment, supply the environment such as
  #     'development', 'production'
  def self.install!(base: ActiveRecord::Base, adapter_class: nil, environment: nil)
    replica_config = base.configurations[environment || Rails.env]["replica"]
    unless replica_config
      base.logger.info("ActiveRecordReplica not installed since no replica database defined")
      return false
    end

    # When the DBMS is not available, an exception (e.g. PG::ConnectionBad) is raised
    active_db_connection = begin
      ActiveRecord::Base.connection.active?
    rescue StandardError
      false
    end

    unless active_db_connection
      base.logger.info("ActiveRecord not connected so not installing ActiveRecordReplica")
      return
    end

    version = ActiveRecordReplica::VERSION
    if ActiveRecord::VERSION::MAJOR >= 6
      base.logger.info("ActiveRecordReplica.install! v#{version} redirecting reads to role: :reading")
    else
      base.logger.info("ActiveRecordReplica.install! v#{version} Establishing connection to replica database")
      Replica.establish_connection(replica_config)
    end

    # Inject a new #select method into the ActiveRecord Database adapter
    adapter_class ||= base.connection.class
    adapter_class.include(Extensions)
    true
  end

  # Force reads for the supplied block to read from the primary database.
  # Only applies to calls made within the current thread.
  #
  # Note:
  #   * This block overrides any value set with read_from_replica!
  def self.read_from_primary(&block)
    thread_variable_yield(:active_record_replica, :primary, &block)
  end

  # Force reads for the supplied block to read from the replica database.
  # Only applies to calls made within the current thread.
  #
  # Note:
  #   * This block overrides any value set with read_from_primary!
  def self.read_from_replica(&block)
    thread_variable_yield(:active_record_replica, :replica, &block)
  end

  # When only reading from a replica it is important to prevent entering any into
  # a transaction since the transaction still sends traffic to the primary
  # that will cause the primary database to slow down processing empty transactions.
  def self.block_transactions
    thread_variable_yield(:active_record_replica_transaction, :block, &block)
  end

  # During this block any attempts to start or end transactions will be ignored.
  # This extreme action should only be taken when 100% certain no writes are going to be
  # performed.
  def self.skip_transactions
    thread_variable_yield(:active_record_replica_transaction, :skip, &block)
  end

  # Whether this thread is currently forcing all reads to go against the primary database
  def self.read_from_primary?
    !read_from_replica?
  end

  # Whether this thread is currently forcing all reads to go against the replica database
  def self.read_from_replica?
    case Thread.current.thread_variable_get(:active_record_replica)
    when :primary
      false
    when :replica
      true
    else
      @read_from_replica
    end
  end

  # Force all subsequent reads in this process to read from the primary database.
  #
  # The default behavior can be set to read/write operations against primary.
  # Create an initializer file config/initializer/active_record_replica.rb
  # and set ActiveRecordReplica.read_from_primary! to force read from primary.
  #
  # Blocks of code can override this setting by calling .read_from_replica.
  def self.read_from_primary!
    @read_from_replica = false
  end

  # Force all subsequent reads in this process to read from the replica database.
  #
  # Blocks of code can override this setting by calling .read_from_primary.
  def self.read_from_replica!
    @read_from_replica = true
  end

  # Whether any attempt to start a transaction should result in an exception
  def self.block_transactions?
    thread_variable_equals(:active_record_replica_transaction, :block)
  end

  # Whether any attempt to start a transaction should be skipped.
  def self.skip_transactions?
    thread_variable_equals(:active_record_replica_transaction, :skip)
  end

  # Returns whether replica reads are ignoring transactions
  def self.ignore_transactions?
    @ignore_transactions
  end

  # Set whether replica reads should ignore transactions
  def self.ignore_transactions=(ignore_transactions)
    @ignore_transactions = ignore_transactions
  end

  def self.thread_variable_equals(key, value)
    Thread.current.thread_variable_get(key) == value
  end

  # Sets the thread variable for the duration of the supplied block.
  # Restores the previous value on completion of the block.
  def self.thread_variable_yield(key, new_value)
    previous = Thread.current.thread_variable_get(key)
    return yield if previous == new_value

    begin
      Thread.current.thread_variable_set(key, new_value)
      yield
    ensure
      Thread.current.thread_variable_set(key, previous)
    end
  end

  @ignore_transactions = false
  @read_from_replica   = true
end
