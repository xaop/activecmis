module ActiveCMIS
  class Object
    include Internal::Caching

    attr_reader :repository, :used_parameters
    attr_reader :key
    alias id key

    def initialize(repository, data, parameters)
      @repository = repository
      @data = data

      @updated_attributes = []

      if @data.nil?
        # Creating a new type from scratch
        raise "This type is not creatable" unless self.class.creatable
        @key = parameters["id"]
        @allowable_actions = {}
        @parent_folders = [] # start unlinked
      else
        @key = parameters["id"] || attribute('cmis:objectId')
        @self_link = data.xpath("at:link[@rel = 'self']/@href", NS::COMBINED).first
        @self_link = @self_link.text
      end
      @used_parameters = parameters
      # FIXME: decide? parameters to use?? always same ? or parameter with reload ?
    end

    def inspect
      "#<#{self.class.inspect} @key=#{key}>"
    end

    def name
      attribute('cmis:name')
    end
    cache :name

    attr_reader :updated_attributes

    def attribute(name)
      attributes[name]
    end

    def attributes
      self.class.attributes.inject({}) do |hash, (key, attr)|
        if data.nil?
          if key == "cmis:objectTypeId"
            hash[key] = self.class.id
          else
            hash[key] = nil
          end
        else
          properties = data.xpath("cra:object/c:properties", NS::COMBINED)
          values = attr.extract_property(properties)
          hash[key] = if values.nil? || values.empty?
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
        end
        hash
      end
    end
    cache :attributes

    # Updates the given attributes, without saving the document
    # Use save to make these changes permanent and visible outside this instance of the document
    # (other #reload after save on other instances of this document to reflect the changes)
    def update(attributes)
      attributes.each do |key, value|
        if (property = self.class.attributes[key.to_s]).nil?
          raise "You are trying to add an unknown attribute (#{key})"
        else
          property.validate_ruby_value(value)
        end
      end
      self.updated_attributes.concat(attributes.keys).uniq!
      self.attributes.merge!(attributes)
    end

    def save
      if @key.nil?
        # Are all required attributes filled in?
        if self.class.required_attributes.any? {|a, _| attribute(a).nil? }
          raise "Not all required attributes are filled in"
        end

        # FIXME: remove redundancy with put?
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.entry(NS::COMBINED) do
            xml.parent.namespace = xml.parent.namespace_definitions.detect {|ns| ns.prefix == "at"}
            xml["at"].author do
              xml["at"].name conn.user # FIXME: find reliable way to set author?
            end
            xml["at"].id_ do xml.text "blah" end
            xml["cra"].object do
              xml["c"].properties do
                self.class.attributes.each do |key, definition|
                  if updated_attributes.include?(key) || definition.required
                    definition.render_property(xml, attributes[key])
                  end
                end
              end
            end
          end
        end
        body = builder.to_xml

        # Keep link to current parent_folders for linking afterwards
        all_folders = parent_folders.to_a

        url = create_url
        response = conn.post(create_url, body, "Content-Type" => "application/xmiatom+xml;type=entry")
        # XXX: Currently ignoring Location header in response

        response_data = Nokogiri::XML::parse(response).xpath("at:entry", NS::COMBINED) # Assume that a response indicates success?

        @self_link = response_data.xpath("at:link[@rel = 'self']/@href", NS::COMBINED).first
        @self_link = @self_link.text
        reload
        @key  = attribute("cmis:objectId")

        # to_a needed because parent_folders can be a Collection
        unless (extra_folders = all_folders - parent_folders.to_a).empty?
          extra_folders.each do |f|
            file(f)
          end
          save
        end

        self
      else
        # TODO: implement updating linking when saving ordinarily
        response = put(false, nil, nil)
      end
    end

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

    # :section: Relationships
    # FIXME: this needs to be Folder and Document only

    def target_relations
      query = "at:link[@rel = 'http://docs.oasis-open.org/ns/cmis/link/200908/relationships']/@href"
      link = data.xpath(query, NS::COMBINED)
      if link.length == 1
        link = Internal::Utils.append_parameters(link.text, "relationshipDirection" => "target", "includeSubRelationshipTypes" => true)
        Collection.new(repository, link)
      else
        raise "Expected exactly 1 relationships link for #{key}, got #{link.length}, are you sure this is a document/folder"
      end
    end
    cache :target_relations

    def source_relations
      query = "at:link[@rel = 'http://docs.oasis-open.org/ns/cmis/link/200908/relationships']/@href"
      link = data.xpath(query, NS::COMBINED)
      if link.length == 1
        link = Internal::Utils.append_parameters(link.text, "relationshipDirection" => "source", "includeSubRelationshipTypes" => true)
        Collection.new(repository, link)
      else
        raise "Expected exactly 1 relationships link for #{key}, got #{link.length}, are you sure this is a document/folder"
      end
    end
    cache :source_relations

    # :section: ACL
    # All 4 subtypes can have an acl
    def acl
      if repository.acls_readable? && allowable_actions["GetACL"]
        # FIXME: actual query should perhaps look at CMIS version before deciding which relation is applicable?
        query = "at:link[@rel = 'http://docs.oasis-open.org/ns/cmis/link/200908/acl']/@href"
        link = data.xpath(query, NS::COMBINED)
        if link.length == 1
          Acl.new(repository, self, link.first.text, data.xpath("cra:object/c:acl", NS::COMBINED))
        else
          raise "Expected exactly 1 acl for #{key}, got #{link.length}"
        end
      end
    end

    # :section: Fileable

    # Depending on the repository there can be more than 1 parent folder
    # Always returns [] for relationships, policies may also return []
    def parent_folders
      query = "at:link[@rel = 'up' and @type = 'application/atom+xml;type=%s']/@href"
      parent_feed = data.xpath(query % 'feed', NS::COMBINED)
      unless parent_feed.empty?
        Collection.new(repository, parent_feed.to_s)
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

    def file(folder)
      raise "Not supported" unless self.class.fileable
      @original_parent_folders ||= parent_folders.dup
      if repository.capabilities["MultiFiling"]
        @parent_folders << folder
      else
        @parent_folders = [folder]
      end
    end

    # FIXME: should throw exception if folder is not actually in @parent_folders?
    def unfile(folder = nil)
      raise "Not supported" unless self.class.fileable
      @original_parent_folders ||= parent_folders.dup
      if repository.capabilities["UnFiling"]
        if folder.nil?
          @parent_folders = []
        else
          @parent_folders.delete(folder)
        end
      elsif @parent_folders.length > 1
        @parent_folders.delete(folder)
      else
        raise "Unfiling not supported by the repository"
      end
    end

    def reload
      if @self_link.nil?
        raise "Can't reload unsaved object"
      else
        __reload
      end
    end

    private
    def self_link(options = {})
      url = @self_link
      if options.empty?
        url
      else
        Internal::Utils.append_parameters(url, options)
      end
      #repository.object_by_id_url(options.merge("id" => id))
    end

    def data
      parameters = {"includeAllowableActions" => true, "renditionFilter" => "*", "includeACL" => true}
      data = conn.get_atom_entry(self_link(parameters))
      @used_parameters = parameters
      data
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

    attr_writer :updated_attributes
    def put(checkin, major, checkin_comment)
      specified_attributes = []
      if updated_attributes.empty?
        if !checkin
          return self
        end
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
                self.class.attributes.each do |key, definition|
                  next if definition.updatability == "oncreate" && attribute("cmis:objectId")
                  if updated_attributes.include?(key) || definition.required
                    definition.render_property(xml, attributes[key])
                    specified_attributes << key
                  end
                end
              end
            end
          end
        end
        body = builder.to_xml
      end
      unless nonexistent_attributes = (updated_attributes - specified_attributes).empty?
        raise "You updated attributes (#{nonexistent_attributes.join ','}) that are not defined in the type #{self.class.key}"
      end
      parameters = {"checkin" => !!checkin}
      if checkin
        parameters.merge! "major" => !!major, "checkin_comment" => Internal::Utils.escape_url_parameter(checkin_comment)
      end
      if ct = attribute("cmis:changeToken")
        parameters.merge! "changeToken" => Internal::Utils.escape_url_parameter(ct)
      end
      uri = self_link(parameters)
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

    class << self
      attr_reader :repository

      def from_atom_entry(repository, data, parameters = {})
        query = "cra:object/c:properties/c:propertyId[@propertyDefinitionId = '%s']/c:value"
        type_id = data.xpath(query % "cmis:objectTypeId", NS::COMBINED).text
        klass = repository.type_by_id(type_id)
        if klass
          if klass <= self
            klass.new(repository, data, parameters)
          else
            raise "You tried to do from_atom_entry on a type which is not a supertype of the type of the document you identified"
          end
        else
          raise "The object #{extract_property(data, "String", 'cmis:name')} has an unrecognized type #{type_id}"
        end
      end

      def from_parameters(repository, parameters)
        url = repository.object_by_id_url(parameters)
        data = repository.conn.get_atom_entry(url)
        from_atom_entry(repository, data, parameters)
      end

      def attributes(inherited = false)
        {}
      end

      # This does not actually reload the type definition, but clears all cached values
      # This means reloading is fast, but accessing after the first load will be slow
      def reload
        # Note: reloading of Object does do nothing, simply because there is nothing repository specific
        []
      end

      def key
        raise NotImplementedError
      end

    end
  end
end
