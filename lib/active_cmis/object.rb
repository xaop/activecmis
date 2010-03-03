module ActiveCMIS
  class Object
    include Internal::Caching

    attr_reader :repository

    def initialize(repository, data)
      @repository = repository
      @data = data
      @self_link = URI.parse(data.xpath("at:link[@rel = 'self']/@href", NS::COMBINED).text)
    end

    def inspect
      "#<#{self.class.inspect} @key=#{key}>"
    end

    def key
      attribute('cmis:objectId')
    end
    cache :key
    alias id key

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
                      if attr.repeating
                        []
                      else
                        nil
                      end
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


    def allowable_actions
      actions = {}
      _allowable_actions.children.map do |node|
        actions[node.name.sub("can", "")] = case t = node.text
                                            when "true", "1"; true
                                            when "false", "0"; false
                                            else t
                                            end
      end
      actions
    end
    cache :allowable_actions

    # :section: Fileable

    # Depending on the repository there can be more than 1 parent folder
    # Always returns [] for relationships, policies may also return []
    def parent_folders
      query = "at:link[@rel = 'up' and @type = 'application/atom+xml;type=%s']/@href"
      parent_feed = data.xpath(query % 'feed', NS::COMBINED)
      unless parent_feed.empty?
        feed = conn.get_xml(parent_feed.to_s)
        feed.xpath('at:feed/at:entry', NS::COMBINED).map do |e|
          ActiveCMIS::Object.from_atom_entry(repository, e)
        end
      else
        parent_entry = @data.xpath(query % 'entry', NS::COMBINED)
        unless parent_entry.empty?
          e = conn.get_atom_entry(parent_feed.to_s)
          [ActiveCMIS::Object.from_atom_entry(repository, e)]
        else
          []
        end
      end
    end
    cache :parent_folders

    private
    def self_link(options = nil)
      if options.nil?
        @self_link
      else
        uri = @self_link.dup
        uri.query = [uri.query, *options.map {|key, value| "#{key}=#{value}"} ].compact.join "&"
        uri
      end
    end

    def data
      conn.get_atom_entry(self_link("includeAllowableActions" => true))
    end
    cache :data

    def conn
      @repository.conn
    end

    def _allowable_actions
      if actions = data.xpath('cra:object/c:allowableActions', NS::COMBINED).first
        actions
      else
        links = data.xpath("at:link[@rel = 'http://docs.oasis-open.org/ns/cmis/link/200908/allowableactions']/@href", NS::COMBINED)
        if link = links.first
          conn.get_xml(link.text)
        else
          nil
        end
      end
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
