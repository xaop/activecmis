module ActiveCMIS
  module Internal
    class Connection
      attr_reader :user, :logger

      def initialize(logger)
        @logger = logger || ActiveCMIS.default_logger
      end

      def authenticate(method, *params)
        case method
        when :basic
          @authentication = {:method => :basic_auth, :params => params}
          @user = params.first
        else raise "Authentication method not supported"
        end
      end

      # The return value is the unparsed body, unless an error occured
      # If an error occurred, exceptions are thrown (see _ActiveCMIS::Exception
      def get(url)
        uri = normalize_url(url)

        req = Net::HTTP::Get.new(uri.request_uri)
        handle_request(uri, req)
      end

      # Does not throw errors, returns the full response (includes status code and headers)
      def get_response(url)
        logger.debug "GET (response) #{url}"
        uri = normalize_url(url)

        req = Net::HTTP::Get.new(uri.request_uri)
        http = authenticate_request(uri, req)
        response = http.request(req)
        logger.debug "GOT (#{response.code}) #{url}"
        response
      end

      # Returns the parsed body of the result
      def get_xml(url)
        Nokogiri::XML.parse(get(url))
      end

      def get_atom_entry(url)
        # FIXME: add validation that first child is really an entry
        get_xml(url).child
      end

      def put(url, body, headers = {})
        uri = normalize_url(url)

        req = Net::HTTP::Put.new(uri.request_uri)
        headers.each {|k,v| req.add_field k, v}
        assign_body(req, body)
        handle_request(uri, req)
      end

      def post(url, body, headers = {})
        uri = normalize_url(url)

        req = Net::HTTP::Post.new(uri.request_uri)
        headers.each {|k,v| req.add_field k, v}
        assign_body(req, body)
        handle_request(uri, req)
      end

      # Does not throw errors, returns the full response (includes status code and headers)
      def post_response(url, body, headers = {})
        logger.debug "POST (response) #{url}"
        uri = normalize_url(url)

        req = Net::HTTP::Post.new(uri.request_uri)
        headers.each {|k,v| req.add_field k, v}
        assign_body(req, body)

        http = authenticate_request(uri, req)
        response = http.request(req)
        logger.debug "POSTED (#{response.code}) #{url}"
        response
      end

      def delete(url)
        uri = normalize_url(url)

        req = Net::HTTP::Delete.new(uri.request_uri)
        handle_request(uri, req)
      end

      private
      def normalize_url(url)
        case url
        when URI; url
        else URI.parse(url.to_s)
        end
      end

      def authenticate_request(uri, req)
        http = Net::HTTP.new(uri.host, uri.port)
        if uri.scheme == 'https'
          http.use_ssl = true
        end
        if auth = @authentication
          req.send(auth[:method], *auth[:params])
        end
        http
      end

      def assign_body(req, body)
        if body.respond_to? :length
          req.body = body
        else
          req.body_stream = body
          if body.respond_to? :stat
            req["Content-Length"] = body.stat.size.to_s
          elsif req["Content-Size"].nil?
            req["Transfer-Encoding"] = 'chunked'
          end
        end
      end

      def handle_request(uri, req)
        logger.debug "#{req.method} #{uri}"
        http = authenticate_request(uri, req)
        response = http.request(req)
        status = response.code.to_i
        logger.debug "RECEIVED #{response.code}"
        if 200 <= status && status < 300
          return response.body
        else
          # Problem: some codes 400, 405, 403, 409, 500 have multiple meanings
          logger.error "Error occurred when handling request:\n#{response.body}"
          case status
          when 400; raise Error::InvalidArgument.new(response.body)
            # FIXME: can also be filterNotValid
          when 404; raise Error::ObjectNotFound.new(response.body)
          when 403; raise Error::PermissionDenied.new(response.body)
            # FIXME: can also be streamNotSupported (?? shouldn't that be 405??)
          when 405; raise Error::NotSupported.new(response.body)
          else
            raise HTTPError.new("A HTTP #{status} error occured, for more precision update the code:\n" + response.body)
          end
        end
      end
    end
  end
end
