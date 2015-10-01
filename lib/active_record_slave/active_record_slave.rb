#
# ActiveRecord read from a slave
#
module ActiveRecordSlave

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
    slave_config = if ActiveRecord::Base.connection.respond_to?(:config)
      ActiveRecord::Base.connection.config[:slave]
    else
      ActiveRecord::Base.configurations[environment || Rails.env]['slave']
    end
    if slave_config
      ActiveRecord::Base.logger.info "ActiveRecordSlave.install! v#{ActiveRecordSlave::VERSION} Establishing connection to slave database"
      Slave.establish_connection(slave_config)

      # Inject a new #select method into the ActiveRecord Database adapter
      base = adapter_class || ActiveRecord::Base.connection.class
      base.send(:include, InstanceMethods)
      SELECT_METHODS.each do |select_method|
        base.alias_method_chain(select_method, :slave_reader)
      end
    else
      ActiveRecord::Base.logger.info "ActiveRecordSlave not installed since no slave database defined"
    end
  end

  # Force reads for the supplied block to read from the master database
  # Only applies to calls made within the current thread
  def self.read_from_master
    return yield if read_from_master?
    begin
      # Set :master indicator in thread local storage so that it is visible
      # during the select call
      read_from_master!
      yield
    ensure
      read_from_slave!
    end
  end

  # Whether this thread is currently forcing all reads to go against the master database
  def self.read_from_master?
    thread_variable_get(:active_record_slave) == :master
  end

  # Force all subsequent reads on this thread and any fibers called by this thread to go the master
  def self.read_from_master!
    thread_variable_set(:active_record_slave, :master)
  end

  # Subsequent reads on this thread and any fibers called by this thread can go to a slave
  def self.read_from_slave!
    thread_variable_set(:active_record_slave, nil)
  end

  # Returns whether slave reads are ignoring transactions
  def self.ignore_transactions?
    @ignore_transactions
  end

  # Set whether slave reads should ignore transactions
  def self.ignore_transactions=(ignore_transactions)
    @ignore_transactions = ignore_transactions
  end

  ##############################################################################
  private

  @ignore_transactions = false

  # Returns the value of the local thread variable
  #
  # Parameters
  #   variable [Symbol]
  #     Name of variable to get
  if (RUBY_VERSION.to_i >= 2) && !defined?(Rubinius::VERSION)
    # Fibers have their own thread local variables so use thread_variable_get
    def self.thread_variable_get(variable)
      Thread.current.thread_variable_get(variable)
    end
  else
    def self.thread_variable_get(variable)
      Thread.current[variable]
    end
  end

  # Sets the value of the local thread variable
  #
  # Parameters
  #   variable [Symbol]
  #     Name of variable to set
  #   value [Object]
  #     Value to set the thread variable to
  if (RUBY_VERSION.to_i >= 2) && !defined?(Rubinius::VERSION)
    # Fibers have their own thread local variables so use thread_variable_set
    def self.thread_variable_set(variable, value)
      Thread.current.thread_variable_set(variable, value)
    end
  else
    def self.thread_variable_set(variable, value)
      Thread.current[variable] = value
    end
  end

end
