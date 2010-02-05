module ActiveCMIS
  class Repository
    def initialize(connection, id) #:nodoc:
      @connection = connection
      @id = id
    end
  end
end
