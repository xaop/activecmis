module ActiveCMIS
  class Object
    include Internal::Caching

    def initialize(conn, data)
      @conn = conn
      @data = data
      @self_link = data.xpath("at:link[@rel = 'self']/@href", NS::COMBINED).text
    end

    def inspect
      "<##{self.class.inspect} #{key}>"
    end

    def key
      @key ||= data.xpath("cra:object/c:properties/c:propertyId[@propertyDefinitionId = 'cmis:objectId']/c:value", NS::COMBINED).text
    end

    class << self
      def from_atom_entry(conn, data)
        # type_id = xpath("cra:object/c:properties/c:propertyId[@propertyDefinitionId = 'cmis:objectTypeId']/c:value", NS::COMBINED).text
        type_id = data.xpath("cra:object/c:properties/c:propertyId[@propertyDefinitionId = 'cmis:baseTypeId']/c:value", NS::COMBINED).text

        # FIXME: flesh this out a bit more? Look at objectTypeId not baseTypeId ?
        #        make custom classes for the given type_id and do new on that? (i.e. like ActiveDCTM?)
        case type_id
        when 'cmis:document'
          Document.new(conn, data)
        when 'cmis:folder'
          Folder.new(conn, data)
        when 'cmis:relationship'
          Relationship.new(conn, data)
        when 'cmis:policy'
          Policy.new(conn, data)
        else
          raise "The repository has an unrecognized base type #{type_id}, this is not allowed by the CMIS spec"
        end
      end
    end

    private
    attr_reader :self_link
    def conn
      @conn
    end

    def data
      Nokogiri.parse(conn.get(self_link)).xpath('at:entry', NS::COMBINED)
    end
    cache :data
  end
end
