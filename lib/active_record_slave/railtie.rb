module ActiveRecordSlave #:nodoc:
  class Railtie < Rails::Railtie #:nodoc:

    # Make the ActiveRecordSlave configuration available in the Rails application config
    #
    # Example: For this application ignore the current transactions since the application
    #          has been coded to use ActiveRecordSlave.read_from_master whenever
    #          the current transaction must be visible to reads.
    #            In file config/application.rb
    #
    #   Rails::Application.configure do
    #     # Read from slave even when in an active transaction
    #     # The application will use ActiveRecordSlave.read_from_master to make
    #     # changes in the current transaction visible to reads
    #     config.active_record_slave.ignore_transactions = true
    #   end
    config.active_record_slave = ::ActiveRecordSlave

    # Initialize ActiveRecordSlave
    initializer "load active_record_slave", :after => "active_record.initialize_database" do
      ActiveRecordSlave.install!
    end

  end
end
