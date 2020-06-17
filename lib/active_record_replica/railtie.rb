module ActiveRecordReplica
  class Railtie < Rails::Railtie
    # Make the ActiveRecordReplica configuration available in the Rails application config
    #
    # Example: For this application ignore the current transactions since the application
    #          has been coded to use ActiveRecordReplica.read_from_primary whenever
    #          the current transaction must be visible to reads.
    #            In file config/application.rb
    #
    #   Rails::Application.configure do
    #     # Read from replica even when in an active transaction
    #     # The application will use ActiveRecordReplica.read_from_primary to make
    #     # changes in the current transaction visible to reads
    #     config.active_record_replica.ignore_transactions = true
    #   end
    config.active_record_replica = ::ActiveRecordReplica

    # Initialize ActiveRecordReplica
    initializer "load active_record_replica", after: "active_record.initialize_database" do
      ActiveRecordReplica.install!
    end

  end
end
