module ActiveCMIS
  module Type
    def self.create(param_conn, repository, klass_data)
      parent_id = klass_data.xpath("cra:type/c:parentId", NS::COMBINED)
      superclass = if parent_id.first
                     repository.type_by_id(parent_id.text)
                   else
                     base_type_id = klass_data.xpath("cra:type/c:baseId", NS::COMBINED).text
                     case base_type_id
                     when "cmis:document"
                       Document
                     when "cmis:folder"
                       Folder
                     when "cmis:relationship"
                       RelationShipt
                     when "cmis:policy"
                       Policy
                     else
                       raise ActiveCMIS::Error.new("Type #{klass_data.xpath("cra:type/c:id", NS::COMBINED).text} without supertype, and not actually a valid base_type (#{base_type_id.inspect})\n" + klass_data.to_s)
                     end
                   end

      klass = ::Class.new(superclass) do
        extend ActiveCMIS::Type::ClassMethods

        @repository = repository
        @conn = param_conn
        @data = klass_data
        @self_link = klass_data.xpath("at:link[@rel = 'self']/@href", NS::COMBINED).text
      end
      klass
    end

    module ClassMethods
      include Internal::Caching

      cached_reader :id, :local_name, :local_namespace, :display_name, :query_name, :description, :base_id,
        :parent_id, :creatable, :fileable, :queryable, :fulltext_indexed, :controllable_policy, :controllable_acl,
        :versionable, :content_stream_allowed

      def attributes(inherited = false)
        load_from_data unless defined?(@attributes)
        if inherited && superclass.respond_to?(:attributes)
          super.merge(@attributes)
        else
          @attributes
        end
      end

      # defaults to all attributes (inherited and non-inherited)
      def required_attributes
        attributes(true).reject {|key, value| !value.required}
      end

      alias imported_reload reload
      def reload
        remove_instance_variable(:@attributes) if defined? @attributes
        imported_reload
      end

      def inspect
        "#<#{repository.key}::Class #{key}>"
      end

      def key
        @key ||= data.xpath("cra:type/c:id", NS::COMBINED).text
      end

      private
      attr_reader :self_link, :conn
      def data
        @data ||= conn.get_atom_entry(self_link)
      end
      cache :data

      def load_from_data
        @attributes = {}
        data.xpath('cra:type', NS::COMBINED).children.each do |node|
          next unless node.namespace
          next unless node.namespace.href == NS::CMIS_CORE

          case node.node_name
          when "id"
            @id = node.text
          when "localName"
            @local_name = node.text
          when "localNamespace"
            @local_namespace = node.text
          when "displayName"
            @display_name = node.text
          when "queryName"
            @query_name = node.text
          when "description"
            @description = node.text
          when "baseId"
            @base_id = node.text
          when "parentId"
            @parent_id = node.text
          when "creatable"
            @creatable = AtomicType::Boolean.xml_to_bool(node.text)
          when "fileable"
            @fileable = AtomicType::Boolean.xml_to_bool(node.text)
          when "queryable"
            @queryable = AtomicType::Boolean.xml_to_bool(node.text)
          when "fulltextIndexed"
            @fulltext_indexed = AtomicType::Boolean.xml_to_bool(node.text)
          when "controllablePolicy"
            @controllable_policy = AtomicType::Boolean.xml_to_bool(node.text)
          when "controllableACL"
            @controllable_acl = AtomicType::Boolean.xml_to_bool(node.text)
          when "versionable"
            @versionable = AtomicType::Boolean.xml_to_bool(node.text)
          when "contentStreamAllowed"
            # FIXME? this is an enumeration, should perhaps wrap
            @content_stream_allowed = node.text
          when /^property(?:DateTime|String|Html|Id|Boolean|Integer|Decimal)Definition$/
            attr = PropertyDefinition.new(self, node.children)
            @attributes[attr.id] = attr
          end
        end
        @attributes.freeze
      end
    end
  end
end
