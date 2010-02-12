module ActiveCMIS
  # This class is used to manage the different CMIS endpoints.
  class Connection
    # A connection needs the URL to a CMIS REST endpoint.
    #
    # It's used to manage all communication with the CMIS Server
    def initialize(endpoint)
      # Add exception checking
      @repository_info = Nokogiri.parse(Net::HTTP.get(endpoint))
    end

    # Returns the _Repository identified by the ID
    def repository(repository_id)
      repository_data = @repository_info.xpath("/app:service/app:workspace[cra:repositoryInfo/c:repositoryId[child::text() = '#{repository_id}']]", NS::COMBINED)
      Repository.new(self, repository_data)
    end

    # Lists all the available repositories
    #
    # Returns an Array of Hashes containing :id and :name
    def repositories
      repositories = @repository_info.xpath("/app:service/app:workspace/cra:repositoryInfo", NS::COMBINED)
      repositories.map {|ri| next {:id => ri.xpath("ns:repositoryId", "ns" => NS::CMIS_CORE).text,
        :name => ri.xpath("ns:repositoryName", "ns" => NS::CMIS_CORE).text }}
    end
  end
end
