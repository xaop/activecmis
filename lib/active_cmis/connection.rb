module ActiveCMIS
  # This class is used to manage the different CMIS endpoints.
  class Connection
    # An connection needs the URL to a CMIS SOAP endpoint.
    #
    # It's used to manage all communication with the CMIS Server
    def initialize(endpoint)
    end

    # Returns the _Repository identified by the ID
    def connect(repository_id)
      Repository.new(self, repository_id)
    end

    # Lists all the available repositories
    #
    # Returns an Array of Hashes containing :id and :name
    def repositories
    end
  end
end
