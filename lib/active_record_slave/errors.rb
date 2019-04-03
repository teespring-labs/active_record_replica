module ActiveRecordSlave
  # Attempting to start a transaction during a read-only database connection.
  class TransactionAttempted < StandardError
  end
end
