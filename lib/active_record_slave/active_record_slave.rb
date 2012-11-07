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
      base.alias_method_chain(:select, :slave_reader)
    else
      ActiveRecord::Base.logger.info "ActiveRecordSlave no slave database defined"
    end
  end

  # Force reads for the supplied block to read from the master database
  # Only applies to calls made within the current thread
  def self.read_from_master
    # Set :master indicator in thread local storage so that it is visible
    # during the select call
    current = Thread.current[:active_record_slave]
    Thread.current[:active_record_slave] = :master
    yield
  ensure
    Thread.current[:active_record_slave] = current
  end

end

