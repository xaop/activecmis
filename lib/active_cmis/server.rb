module ActiveCMIS
  # This class is used to manage different CMIS servers.
  class Server
    include Internal::Caching
    # @return [URI] The location of the server
    attr_reader :endpoint
    # @return [Logger] A default logger for derived repositories
    attr_reader :logger

    # @return [Server] Cached by endpoint and logger
    def self.new(endpoint, logger = nil)
      endpoint = case endpoint
                 when URI; endpoint
                 else URI(endpoint.to_s)
                 end
      endpoints[[endpoint, logger]] ||= super(endpoint, logger || ActiveCMIS.default_logger)
    end

    # @return [{(URI, Logger) => Server}] The cache of known Servers
    def self.endpoints
      @endpoints ||= {}
    end

    # @return [String]
    def inspect
      "Server #{@endpoint}"
    end
    # @return [String]
    def to_s
      "Server " + @endpoint.to_s + " : " + repositories.map {|h| h[:name] + "(#{h[:id]})"}.join(", ")
    end

    # A connection needs the URL to a CMIS REST endpoint.
    #
    # It's used to manage all communication with the CMIS Server
    def initialize(endpoint, logger)
      @endpoint = endpoint
      @logger = logger
    end

    # @param (see ActiveCMIS::Internal::Connection#authenticate)
    # @see Internal::Connection#authenticate
    # @return [void]
    def authenticate(method, *params)
      conn.authenticate(method, *params)
    end

    # Returns the _Repository identified by the ID
    #
    # Cached by the repository_id, no way to reset cache yet
    # @param [String] repository_id
    # @return [Repository]
    def repository(repository_id)
      cached_repositories[repository_id] ||= begin
                                               repository_data = repository_info.
                                                 xpath("/app:service/app:workspace[cra:repositoryInfo/c:repositoryId[child::text() = '#{repository_id}']]", NS::COMBINED)
                                               if repository_data.empty?
                                                 raise Error::ObjectNotFound.new("The repository #{repository_id} doesn't exist")
                                               else
                                                 Repository.new(conn.dup, logger.dup, repository_data)
                                               end
                                             end
    end

    # Lists all the available repositories
    #
    # @return [<{:id, :name} => String>]
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
      @conn ||= Internal::Connection.new(logger.dup)
    end
  end
end
