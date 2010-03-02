module ActiveCMIS
  # This class is used to manage different CMIS servers.
  class Server
    include Internal::Caching
    attr_reader :endpoint

    def self.new(endpoint)
      endpoints[endpoint] ||= super
    end

    def self.endpoints
      @endpoints ||= {}
    end

    # A connection needs the URL to a CMIS REST endpoint.
    #
    # It's used to manage all communication with the CMIS Server
    def initialize(endpoint)
      @endpoint = case endpoint
                  when URI; endpoint
                  else URI(endpoint.to_s)
                  end
    end

    # Use authentication to access the CMIS repository
    #
    # e.g.: repo.authenticate(:basic, "username", "password")
    def authenticate(method, *params)
      conn.authenticate(method, *params)
    end

    # Returns the _Repository identified by the ID
    #
    # Cached by the repository_id, no way to reset cache yet
    def repository(repository_id)
      cached_repositories[repository_id] ||= begin
                                               repository_data = repository_info.
                                                 xpath("/app:service/app:workspace[cra:repositoryInfo/c:repositoryId[child::text() = '#{repository_id}']]", NS::COMBINED)
                                               if repository_data.empty?
                                                 raise Error::ObjectNotFound.new("The repository #{repository_id} doesn't exist")
                                               else
                                                 Repository.new(conn.dup, repository_data)
                                               end
                                             end
    end

    # Lists all the available repositories
    #
    # Returns an Array of Hashes containing :id and :name
    def repositories
      repositories = repository_info.xpath("/app:service/app:workspace/cra:repositoryInfo", NS::COMBINED)
      repositories.map {|ri| next {:id => ri.xpath("ns:repositoryId", "ns" => NS::CMIS_CORE).text,
        :name => ri.xpath("ns:repositoryName", "ns" => NS::CMIS_CORE).text }}
    end

    private
    def repository_info
      @repository_info ||= conn.get_xml(endpoint)
    end
    cache :repository_info

    def cached_repositories
      @cached_repositories ||= {}
    end

    def conn
      @conn ||= Internal::Connection.new
    end
  end
end
