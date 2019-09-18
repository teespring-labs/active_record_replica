#
# ActiveRecord read from a slave
#
module ActiveRecordSlave
  # Select Methods
  SELECT_METHODS = [:select, :select_all, :select_one, :select_rows, :select_value, :select_values]

  # In case in the future we are forced to intercept connection#execute if the
  # above select methods are not sufficient
  #   SQL_READS = /\A\s*(SELECT|WITH|SHOW|CALL|EXPLAIN|DESCRIBE)/i

  # Install ActiveRecord::Slave into ActiveRecord to redirect reads to the slave
  # Parameters:
  #   adapter_class:
  #     By default, only the default Database adapter (ActiveRecord::Base.connection.class)
  #     is extended with slave read capabilities
  #
  #   environment:
  #     In a non-Rails environment, supply the environment such as
  #     'development', 'production'
  def self.install!(adapter_class = nil, environment = nil)
    slave_config =
      if ActiveRecord::Base.connection.respond_to?(:config)
        ActiveRecord::Base.connection.config[:slave]
      else
        ActiveRecord::Base.configurations[environment || Rails.env]['slave']
      end
    if slave_config
      ActiveRecord::Base.logger.info "ActiveRecordSlave.install! v#{ActiveRecordSlave::VERSION} Establishing connection to slave database"
      Slave.establish_connection(slave_config)

      # Inject a new #select method into the ActiveRecord Database adapter
      base = adapter_class || ActiveRecord::Base.connection.class
      base.include(Extensions)
    else
      ActiveRecord::Base.logger.info "ActiveRecordSlave not installed since no slave database defined"
    end
  end

  # Force reads for the supplied block to read from the master database
  # Only applies to calls made within the current thread
  def self.read_from_master
    return yield if read_from_master?
    begin
      previous = Thread.current.thread_variable_get(:active_record_slave)
      read_from_master!
      yield
    ensure
      Thread.current.thread_variable_set(:active_record_slave, previous)
    end
  end

  #
  # The default behavior can also set to read/write operations against master
  # Create an initializer file config/initializer/active_record_slave.rb
  # and set ActiveRecordSlave.read_from_master! to force read from master.
  # Then use this method and supply block to read from the slave database
  # Only applies to calls made within the current thread
  def self.read_from_slave
    return yield if read_from_slave?
    begin
      previous = Thread.current.thread_variable_get(:active_record_slave)
      read_from_slave!
      yield
    ensure
      Thread.current.thread_variable_set(:active_record_slave, previous)
    end
  end

  # When only reading from a slave it is important to prevent entering any into
  # a transaction since the transaction still sends traffic to the master
  # that will cause the master database to slow down processing empty transactions.
  def self.block_transactions
    begin
      previous = Thread.current.thread_variable_get(:active_record_slave_transaction)
      Thread.current.thread_variable_set(:active_record_slave_transaction, :block)
      yield
    ensure
      Thread.current.thread_variable_set(:active_record_slave_transaction, previous)
    end
  end

  # During this block any attempts to start or end transactions will be ignored.
  # This extreme action should only be taken when 100% certain no writes are going to be
  # performed.
  def self.skip_transactions
    begin
      previous = Thread.current.thread_variable_get(:active_record_slave_transaction)
      Thread.current.thread_variable_set(:active_record_slave_transaction, :skip)
      yield
    ensure
      Thread.current.thread_variable_set(:active_record_slave_transaction, previous)
    end
  end

  # Whether this thread is currently forcing all reads to go against the master database
  def self.read_from_master?
    Thread.current.thread_variable_get(:active_record_slave) == :master
  end

  # Whether this thread is currently forcing all reads to go against the slave database
  def self.read_from_slave?
    Thread.current.thread_variable_get(:active_record_slave).nil?
  end

  # Force all subsequent reads on this thread and any fibers called by this thread to go the master
  def self.read_from_master!
    Thread.current.thread_variable_set(:active_record_slave, :master)
  end

  # Subsequent reads on this thread and any fibers called by this thread can go to a slave
  def self.read_from_slave!
    Thread.current.thread_variable_set(:active_record_slave, nil)
  end

  # Whether any attempt to start a transaction should result in an exception
  def self.block_transactions?
    Thread.current.thread_variable_get(:active_record_slave_transaction) == :block
  end

  # Whether any attempt to start a transaction should be skipped.
  def self.skip_transactions?
    Thread.current.thread_variable_get(:active_record_slave_transaction) == :skip
  end

  # Returns whether slave reads are ignoring transactions
  def self.ignore_transactions?
    @ignore_transactions
  end

  # Set whether slave reads should ignore transactions
  def self.ignore_transactions=(ignore_transactions)
    @ignore_transactions = ignore_transactions
  end

  private

  @ignore_transactions = false
end
