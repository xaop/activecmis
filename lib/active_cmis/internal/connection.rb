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
      #
      # TODO? add a method to get the parsed result (and possibly handle XML errors?)
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
    end
  end
end
