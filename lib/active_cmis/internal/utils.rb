module ActiveCMIS
  module Internal
    module Utils
      def self.escape_url_parameter(parameter)
        control = "\x00-\x1F\x7F"
        space   = " "
        delims  = "<>#%\""
        unwise  = '{}|\\\\^\[\]`'
        query   = ";/?:@&=+,$"
        URI.escape(parameter, /[#{control+space+delims+unwise+query}]/o)
      end
    end

    def self.append_parameters(uri, parameters)
      uri       = case uri
                  when String; string = true; URI.parse(uri)
                  when URI;    uri.dup
                  end
      uri.query = [uri.query, *parameters.map {|key, value| "#{key}=#{value}"} ].compact.join "&"
      if string
        uri.to_s
      else
        uri
      end
    end

    # FIXME?? percent_encode and escape_url_parameter serve nearly the same purpose, replace one?
    def self.percent_encode(string)
      URI.escape(string, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
    end
  end
end
