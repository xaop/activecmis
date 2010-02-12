module ActiveCMIS
  class Repository
    def initialize(connection, data) #:nodoc:
      @connection = connection
      @data = data
    end
  end
end
