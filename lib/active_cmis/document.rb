module ActiveCMIS
  class Document < ActiveCMIS::Object
    attr_reader :updated_attributes

    def initialize(*a)
      super
      @updated_attributes = []
    end

    # Updates the given attributes, without saving the document
    # Use save to make these changes permanent and visible outside this instance of the document
    # (other #reload after save on other instances of this document to reflect the changes)
    def update(attributes)
      self.updated_attributes.concat(attributes.keys).uniq!
      self.attributes.merge!(attributes)
    end

    def save
      response = put(false, nil, nil)
    end

    private
    attr_writer :updated_attributes
    def put(checkin, major, checkin_comment)
      if updated_attributes.empty?
        body = nil
      else
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.entry(NS::COMBINED) do
            xml.parent.namespace = xml.parent.namespace_definitions.detect {|ns| ns.prefix == "at"}
            xml["at"].author do
              xml["at"].name conn.user # FIXME: find reliable way to set author?
            end
            xml["cra"].object do
              xml["c"].properties do
                updated_attributes.each do |key|
                  definition = self.class.attributes[key]
                  if definition
                    definition.render_property(xml, attributes[key])
                  else
                    # FIXME: do this in update method
                    raise "Property updated was not among actual attributes"
                  end
                end
              end
            end
          end
        end
        body = builder.to_xml
      end
      uri = URI.parse(self_link)
      # FIXME: these parameters only come with PWC documents, seems to work with normal OpenCMIS documents though
      #        Solution? use hash and just paste them all? What about escaping though
      uri.query = [uri.query, "checkin=#{!!checkin}", checkin ? "major=#{!!major}" : nil, checkin ? "checkin_comment=#{escape_parameter(checkin_comment)}" : nil].compact.join "&"
      response = conn.put(uri, body)
      updated_attributes.clear
      data = Nokogiri::XML.parse(response).xpath("at:entry", NS::COMBINED)
      if data.xpath("cra:object/c:properties/c:propertyId[@propertyDefinitionId = 'cmis:objectId']/c:value", NS::COMBINED).text == id
        reload
        @data = data
        self
      else
        ActiveCMIS::Object.from_atom_entry(repository, data)
      end
    end

    def escape_parameter(url)
      control = "\x00-\x1F\x7F"
      space   = " "
      delims  = "<>#%\""
      unwise  = '{}|\\\\^\[\]`'
      query   = ";/?:@&=+,$"
      URI.escape(url, /[#{control+space+delims+unwise+query}]/o)
    end
  end
end
