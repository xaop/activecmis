module ActiveCMIS
  class Object
    include Internal::Caching
    def initialize(repository, data)
      @repository = repository
      @data = data
      @self_link = data.xpath("at:link[@rel = 'self']/@href", NS::COMBINED).text
    end

    def inspect
      "#<#{self.class.inspect} @key=#{key}>"
    end

    def key
      attribute('cmis:objectId')
    end
    cache :key

    def name
      attribute('cmis:name')
    end
    cache :name

    def attribute(name)
      attributes[name]
    end

    def attributes
      self.class.attributes.inject({}) do |hash, (key, attr)|
        properties = data.xpath("cra:object/c:properties", NS::COMBINED)
        values = attr.extract_property(properties)
        hash[key] = if values.nil?
                      # attr.extract_property should already have checked that this property is not required
                      nil
                    elsif attr.repeating
                      values.map do |value|
                        attr.property_type.cmis2rb(value)
                      end
                    else
                      attr.property_type.cmis2rb(values.first)
                    end
        hash
      end
    end
    cache :attributes

    private
    attr_reader :self_link

    def data
      conn.get_atom_entry(self_link)
    end
    cache :data

    def conn
      @repository.conn
    end

    class << self
      attr_reader :repository

      def from_atom_entry(repository, data)
        query = "cra:object/c:properties/c:propertyId[@propertyDefinitionId = '%s']/c:value"
        type_id = data.xpath(query % "cmis:objectTypeId", NS::COMBINED).text
        klass = repository.type_by_id(type_id)
        if klass
          if klass <= self
            klass.new(repository, data)
          else
            raise "You tried to do from_atom_entry on a type which is not a supertype of the type of the document you identified"
          end
        else
          raise "The object #{extract_property(data, "String", 'cmis:name')} has an unrecognized type #{type_id}"
        end
      end

      def attributes(inherited = false)
        {}
      end

      # This does not actually reload the type definition, but clears all cached values
      # This means reloading is fast, but accessing after the first load will be slow
      def reload
        raise NotImplementedError
      end

      def key
        raise NotImplementedError
      end

    end
  end
end
