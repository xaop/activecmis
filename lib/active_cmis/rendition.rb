module ActiveCMIS
  class Rendition
    # == Alert
    # Be aware that size and format are not necessarily filled in, and not necessarily correct either if filled in
    attr_reader :repository, :size, :rendition_kind, :format

    def initialize(repository, link)
      @repository = repository

      @rel = link['rel'] == "alternate"
      @rendition_kind = link['renditionKind'] if rendition?
      @format = link['type']
      if link['href']
        @url = URI(link['href'])
      else # For inline content streams
        @data = link['data']
      end
      @size = link['length'] ? link['length'].to_i : nil


      @link = link # FIXME: For debugging purposes only, remove
    end

    def rendition?
      @rel == "alternate"
    end
    def primary?
      @rel.nil?
    end

    # Returns a hash with the name of the file to which was written, the lenthe, and the content type
    #
    #
    # FIXME: flexibility/efficiency
    # flexibility: allow name to unspecified
    # efficiency: currently the whole stream gets loaded in memory before it's written to a file, fix this
    def get_file(file_name)
      if @url
        response = repository.conn.get_response(@url)
        status = response.code.to_i
        if 200 <= status && status < 300
          data = response.body 
        else
          raise HTTPError.new("Problem downloading rendition: status: #{status}, message: #{response.body}")
        end
        content_type = response.content_type
        content_lenth = response.content_length || response.body.length # In case content encoding is chunked? ??
      else
        data = @data
        content_type = @format
        content_length = @data.length
      end
      File.open(file_name, "w") {|f| f.syswrite data }

      {:file => file_name, :content_type => content_type, :content_length => content_length}
    end
  end
end
