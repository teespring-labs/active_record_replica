#
# ActiveRecord read from a slave
#
module ActiveRecordSlave

  # Install ActiveRecord::Slave into ActiveRecord to redirect reads to the slave
  # By default, only the default Database adapter (ActiveRecord::Base.connection.class)
  # is extended with slave read capabilities
  def self.install!(adapter_class = nil)
    if slave_config = ActiveRecord::Base.connection.config[:slave]
      Rails.logger.info "ActiveRecordSlave.install! v#{ActiveRecordSlave::VERSION} Establishing connection to slave database"
      Slave.establish_connection(slave_config)

      # Inject a new #select method into the ActiveRecord Database adapter
      base = adapter_class || ActiveRecord::Base.connection.class
      base.send(:include, InstanceMethods)
      base.alias_method_chain(:select, :slave_reader)
    end
  end

end

