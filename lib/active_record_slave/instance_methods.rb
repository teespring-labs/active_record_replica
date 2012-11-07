module ActiveRecordSlave
  module InstanceMethods

    # Database Adapter method #select is called for every select call
    # Replace #select with one that calls the slave connection instead
    def select_with_slave_reader(sql, name = nil, *args)
      # Only read from slave when not in a transaction and when this is not already the slave connection
      if (open_transactions == 0) && (Thread.current[:active_record_slave] != :master)
        ActiveRecordSlave.read_from_master do
          Slave.connection.select(sql, "Slave: #{name || 'SQL'}", *args)
        end
      else
        select_without_slave_reader(sql, name, *args)
      end
    end

  end
end

