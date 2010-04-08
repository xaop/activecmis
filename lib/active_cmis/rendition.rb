module ActiveCMIS
  class Rendition
    # @return [Repository]
    attr_reader :repository
    # @return [Numeric,nil] Size of the rendition, may not be given or misleading
    attr_reader :size
    # @return [String,nil]
    attr_reader :rendition_kind
    # @return [String,nil] The format is equal to the mime type, but may be unset or misleading
    attr_reader :format

    # @private
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

    # Used to differentiate between rendition and primary content
    def rendition?
      @rel == "alternate"
    end
    # Used to differentiate between rendition and primary content
    def primary?
      @rel.nil?
    end

    # Returns a hash with the name of the file to which was written, the lenthe, and the content type
    #
    # *WARNING*: this loads the complete file in memory and dumps it at once, this should be fixed
    # @param [String] filename Location to store the content.
    # @return [Hash]
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
