module ActiveRecordSlave #:nodoc:
  class Railtie < Rails::Railtie #:nodoc:

    # Initialize ActiveRecordSlave
    initializer "load active_record_slave" , :after=>"active_record.initialize_database" do
      ActiveRecordSlave.install!
    end

  end
end
