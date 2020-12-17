module ActiveRecordReplica
  # Class to hold replica connection pool
  #
  # Note: Not used with Rails 6 and above
  class Replica < ActiveRecord::Base
    # Prevent Rails from trying to create an instance of this model
    self.abstract_class = true

    # Since this is an abstract class so it has no columns
    def self.columns
      []
    end
  end
end
