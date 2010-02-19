module ActiveCMIS
  module Internal
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
      def get(url)
        case url
        when URI; uri = url
        else uri = URI.parse(url.to_s)
        end

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

      def get_xml(url)
        Nokogiri.parse(get(url))
      end

      def get_atom_entry(url)
        # FIXME: add validation that first child is really an entry
        get_xml(url).child
      end
    end
  end
end
