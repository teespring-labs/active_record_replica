module ActiveRecordSlave
  # Class to hold slave connection pool
  class Slave < ActiveRecord::Base
    self.abstract_class = true
  end
end