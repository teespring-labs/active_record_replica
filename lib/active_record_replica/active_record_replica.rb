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
  def self.install!(adapter_class = nil, environment = nil, roles = [:slave], default: :slave)
    roles = roles.map(&:to_sym)

    # When the DBMS is not available, an exception (e.g. PG::ConnectionBad) is raised
    active_db_connection = ActiveRecord::Base.connection.active? rescue false
    unless active_db_connection
      ActiveRecord::Base.logger.info("ActiveRecord not connected so not installing ActiveRecordReplica")
      return
    end

    # Inject a new #select method into the ActiveRecord Database adapter
    base = adapter_class || ActiveRecord::Base.connection.class
    base.include(Extensions)

    roles.each do |role|
      replica_config = ActiveRecord::Base.configurations[environment || Rails.env].symbolize_keys[role.to_sym]
      unless replica_config
        ActiveRecord::Base.logger.info("ActiveRecordReplica not installed since no #{role} database defined")
        next
      end

      version = ActiveRecordReplica::VERSION
      ActiveRecord::Base.logger.info("ActiveRecordReplica.install! v#{version} Establishing connection to #{role} database")

      replica_reader_klass = Class.new(ActiveRecord::Base) do
        # Prevent Rails from trying to create an instance of this model
        self.abstract_class = true

        # Since this is an abstract class so it has no columns
        def self.columns
          []
        end
      end

      const_set("Replica_#{role}", replica_reader_klass)

      replica_reader_klass.establish_connection(replica_config)
    end

    @roles = [:primary] + roles
    read_from!(default)
  end

  # Force reads for the supplied block to read from the primary database
  # Only applies to calls made within the current thread
  def self.read_from_primary(&block)
    read_from(:primary, &block)
  end

  #
  # The default behavior can also set to read/write operations against primary
  # Create an initializer file config/initializer/active_record_replica.rb
  # and set ActiveRecordReplica.read_from_primary! to force read from primary.
  # Then use this method and supply block to read from the replica database
  # Only applies to calls made within the current thread
  def self.read_from(role, &block)
    role = role.to_sym
    assert_role(role)
    thread_variable_yield(:active_record_replica, role, &block)
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
    read_from?(:primary)
  end

  # Whether this thread is currently forcing all reads to go against the replica database
  def self.read_from?(role)
    role = role.to_sym
    assert_role(role)
    if Thread.current.thread_variable_get(:active_record_replica)
      Thread.current.thread_variable_get(:active_record_replica) == role
    else
      @read_from == role
    end
  end

  # Force all subsequent reads in this process to read from the primary database.
  #
  # The default behavior can be set to read/write operations against primary.
  # Create an initializer file config/initializer/active_record_replica.rb
  # and set ActiveRecordReplica.read_from_primary! to force read from primary.
  def self.read_from_primary!
    read_from!(:primary)
  end

  # Force all subsequent reads in this process to read from the replica database.
  def self.read_from!(role)
    role = role.to_sym
    assert_role(role)
    @read_from = role
  end

  def self.current_role
    Thread.current.thread_variable_get(:active_record_replica) || @read_from
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

  private

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

  def self.assert_role(role)
    raise "Undefined role: #{role.inspect}" unless @roles.include?(role)
  end

  @ignore_transactions = false
end
