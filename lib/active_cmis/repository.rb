module ActiveCMIS
  class Repository
    def initialize(connection, data) #:nodoc:
      @connection = connection
      @data = data
      @collections = {}
    end

    # Use authentication to access the CMIS repository
    #
    # e.g.: repo.authenticate(:basic, "username", "password")
    def authenticate(method, *params)
      conn.authenticate(method, *params)
    end

    def key
      @key ||= @data.xpath('cra:repositoryInfo/c:repositoryId', NS::COMBINED).text
    end

    def inspect
      "<#ActiveCMIS::Repository #{key}>"
    end

    def object_by_id(id)
      template = pick_template("objectbyid")
      raise "Repository does not define required URI-template 'objectbyid'" unless template
      url = fill_in_template(template, "id" => id)
      data = Nokogiri.parse(conn.get(url))

      ActiveCMIS::Object.from_atom_entry(conn, data.xpath('at:entry', NS::COMBINED))
    end

    def type_by_id(id)
      template = pick_template("typebyid")
      raise "Repository does not define required URI-template 'typebyid'" unless template
      url = fill_in_template(template, "id" => id)
      data = Nokogiri.parse(conn.get(url))
      # FIXME? Type should be a factory?
      Type.new(conn, data.xpath('at:entry', NS::COMBINED))
    end

    %w[root query checkedout unfiled types].each do |collection|
      define_method collection do
        @collections[collection] ||= begin
                                       href = @data.xpath("app:collection[cra:collectionType[child::text() = '#{collection}']]/@href", NS::COMBINED)
                                       if href
                                         data = Nokogiri.parse(conn.get(href.to_s))
                                         # TODO: we need some kind of collection type
                                         Collection.new(conn, data)
                                       else
                                         nil
                                       end
                                     end
      end
    end

    def root_folder
      id = @data.xpath("cra:repositoryInfo/c:rootFolderId", NS::COMBINED).text
      object_by_id(id)
    end

    private
    def conn
      @conn ||= Repository::Connection.new
    end

    class Connection
      def authenticate(method, *params)
        case method
        when :basic
          @authentication = {:method => :basic_auth, :params => params}
        else raise "Authentication method not supported"
        end
      end

      # The return value is the unparsed body, unless an error occured
      # If an error occurred, exceptions are thrown (see _ActiveCMIS::Exception
      #
      # TODO? add a method to get the parsed result (and possibly handle XML errors?)
      def get(url)
        uri = URI.parse(url)

        http = Net::HTTP.new(uri.host, uri.port)
        req = Net::HTTP::Get.new(uri.request_uri)
        if uri.scheme == 'https'
          http.use_ssl = true
        end
        if auth = @authentication
          req.send(auth[:method], *auth[:params])
        end
        response = http.request req

        status = response.code.to_i
        if 200 <= status && status < 300
          return response.body
        else
          raise HTTPError.new("A HTTP #{status} error occured, for more precision update the code")
        end
      end
    end

    def pick_template(name, options = {})
      # FIXME: we can have more than 1 template with differing media types
      #        I'm not sure how to pick the right one in the most generic/portable way though
      #        So for the moment we pick the 1st and hope for the best
      #        Options are ignored for the moment
      @data.xpath("n:uritemplate[n:type[child::text() = '#{name}']][1]/n:template", "n" => NS::CMIS_REST).text
    end


    # The type parameter should contain the type of the uri-template
    #
    # The keys of the values hash should be strings,
    # if a key is not in the hash it is presumed to be equal to the empty string
    # The values will be percent-encoded in the fill_in_template method
    # If a given key is not present in the template it will be ignored silently
    #
    # e.g. fill_in_template("objectbyid", "id" => "@root@", "includeACL" => true)
    #      -> 'http://example.org/repo/%40root%40?includeRelationships&includeACL=true'
    def fill_in_template(template, values)
      result = template.gsub /\{([^}]+)\}/ do |match|
        percent_encode(values[$1].to_s)
      end
    end

    def percent_encode(string)
      URI.escape(string, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
    end
  end
end
