module ActiveRecordSlave
  module InstanceMethods

    # Database Adapter method #select is called for every select call
    # Replace #select with one that calls the slave connection instead
    def select_with_slave_reader(sql, name = nil)
      # Only read from slave when not in a transaction and when this is not already the slave connection
      if (open_transactions == 0) && !(name && name.starts_with?('Slave: '))
        Slave.connection.select(sql, "Slave: #{name || 'SQL'}")
      else
        select_without_slave_reader(sql, name)
      end
    end

  end
end

