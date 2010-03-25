module ActiveCMIS
  class Document < ActiveCMIS::Object
    # :section: Content
    # Documents can have an attached content stream and renditions.
    # Renditions can't be altered via CMIS, the content stream may be editable

    # Returns an ActiveCMIS::Rendition to the content stream or nil if there is none
    # TODO: test that interpretion of different possibilities is correct
    def content_stream
      if content = data.xpath("at:content", NS::COMBINED).first
        if content['src']
          ActiveCMIS::Rendition.new(repository, "href" => content['src'], "type" => content["type"])
        else
          if content['type'] =~ /\+xml$/
            content_data = content.to_xml # FIXME: this may not preserve whitespace
          else
            content_data = data.unpack("m*").first
          end
          ActiveCMIS::Rendition.new(repository, "data" => content_data, "type" => content["type"])
        end
      elsif content = data.xpath("cra:content", NS::COMBINED).first
        content.children.each do |node|
          next unless node.namespace and node.namespace.href == NS::CMIS_REST
          content_data = node.text if node.name == "base64"
          content_type = node.text if node.name == "mediaType"
        end
        data = content_data.unpack("m*").first
        ActiveCMIS::Rendition.new(repository, "data" => content_data, "type" => content_type)
      end
    end
    cache :content_stream

    # Will reload if renditionFilter was not set or cmis:none, but not in other circumstances
    def renditions
      filter = used_parameters["renditionFilter"]
      if filter.nil? || filter == "cmis:none"
        reload
      end

      links = data.xpath("at:link[@rel = 'alternate']", NS::COMBINED)
      links.map do |link|
        ActiveCMIS::Rendition.new(repository, link)
      end
    end
    cache :renditions

    attr_reader :updated_contents

    # options for content can be :file => filename or :data => binary_data
    # :overwrite defaults to true, if false the content of the document won't be overwritten
    # :mime_type => mime_type
    #
    # This returns the document with the new content, this may be a new version in the version series and as such may not be equal to self
    #
    # Warning: this doesn't update the content stream you get from content_stream (because it is cached)
    def set_content_stream(options)
      updatability = repository.capabilities["ContentStreamUpdatability"]
      if updatability == "none"
        raise "Content can't be updated in this repository"
      elsif updatability == "pwconly" && !working_copy?
        raise "Content can only be updated for working copies in this repository"
      end
      @updated_contents = options
    end

    # :section: Versioning
    # Documents can be versionable, other types of objects are never versionable

    # Returns all documents in the version series of this document.
    # Uses self to represent the version of this document
    def versions
      link = data.xpath("at:link[@rel = 'version-history']/@href", NS::COMBINED)
      if link = link.first
        Collection.new(repository, link) # Problem: does not in fact use self
      else
        # The document is not versionable
        [self]
      end
    end
    cache :versions

    # Returns self if this is the latest version
    # Note: There will allways be a latest version in a version series
    def latest_version
      link = data.xpath("at:link[@rel = 'current-version']/@href", NS::COMBINED)
      if link.first
        entry = conn.get_atom_entry(link.first.text)
        self_or_new(entry)
      else
        # FIXME: should somehow return the current version even for opencmis
        self
      end
    end

    # Returns self if this is the working copy
    # Returns nil if there is no working copy
    def working_copy
      link = data.xpath("at:link[@rel = 'working-copy']/@href", NS::COMBINED)
      if link.first
        entry = conn.get_atom_entry(link.first.text)
        self_or_new(entry)
      else
        nil
      end
    end

    # This may return nil if there are no major versions
    # TODO: implement (no direct link relation exists)
    def latest_major_version
    end

    def latest?
      attributes["cmis:isLatestVersion"]
    end
    def major?
      attributes["cmis:isMajorVersion"]
    end
    def latest_major?
      attributes["cmis:isLatestMajorVersion"]
    end

    def working_copy?
      # NOTE: This may not be a sufficient condition, but according to the spec it should be
      !data.xpath("at:link[@rel = 'via']", NS::COMBINED).empty?
    end

    # Returns nil if the version series has no PWC
    #
    # If a document is checked out then a hash is returned
    # {:by => name, :id => id_of_pwc }
    # Depending on the repository both values may be unset
    def version_series_checked_out
      attributes = self.attributes
      if attributes["cmis:isVersionSeriesCheckedOut"]
        result = {}
        if attributes.has_key? "cmis:versionSeriesCheckedOutBy"
          result[:by] = attributes["cmis:versionSeriesCheckedOutBy"]
        end
        if attributes.has_key? "cmis:versionSeriesCheckedOutId"
          result[:id] = attributes["cmis:versionSeriesCheckedOutId"]
        end
        result
      else
        nil
      end
    end

    # The checkout operation results in a Private Working Copy
    #
    # Most properties should be the same as for the document that was checked out,
    # certain properties may differ such as cmis:objectId and cmis:creationDate.
    #
    # The content stream of the PWC may be identical to that of the document
    # that was checked out, or it may be unset.
    def checkout
      body = render_atom_entry(self.class.attributes.reject {|k,v| k != "cmis:objectId"})

      response = conn.post_response(repository.checkedout.url, body)
      if 200 <= response.code.to_i && response.code.to_i < 300
        entry = Nokogiri::XML.parse(response.body).xpath("/at:entry", NS::COMBINED)
        self_or_new(entry)
      else
        raise response.body
      end
    end

    # This action may not be permitted (query allowable_actions to see whether it is permitted)
    def cancel_checkout
      if working_copy?
        conn.delete(self_link)
      else
        raise "Not a working copy"
      end
    end

    # You can specify whether the new version should be major (defaults to true)
    # You can optionally give a list of attributes that need to be set.
    #
    # This operation exists only for Private Working Copies
    # If the operation succeeds this object becomes the latest in the version series
    def checkin(major = true, comment = "", updated_attributes = {})
      if working_copy?
        update(updated_attributes)
        result = self
        updated_aspects([true, major, comment]).each do |hash|
          result = result.send(hash[:message], *hash[:parameters])
        end
        result
      else
        raise "Not a working copy"
      end
    end

    def reload
      @updated_contents = nil
      super
    end

    # Optional parameters:
    #   - properties: a hash key/definition pairs of properties to be rendered (defaults to all attributes)
    #   - attributes: a hash key/value pairs used to determine the values rendered (defaults to self.attributes)
    def render_atom_entry(properties = self.class.attributes, attributes = self.attributes, options = {})
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.entry(NS::COMBINED) do
          xml.parent.namespace = xml.parent.namespace_definitions.detect {|ns| ns.prefix == "at"}
          xml["at"].author do
            xml["at"].name conn.user # FIXME: find reliable way to set author?
          end
          if updated_contents && options[:create]
            xml["cra"].content do
              xml["cra"].mediatype(updated_contents[:mimetype] || "application/binary")
              data = updated_contents[:data] || File.read(updated_contents[:file])
              xml["cra"].base64 [data].pack("m")
            end
          end
          xml["cra"].object do
            xml["c"].properties do
              properties.each do |key, definition|
                definition.render_property(xml, attributes[key])
              end
            end
          end
        end
      end
      builder.to_xml
    end

    private

    def updated_aspects(*params)
      result = super

      unless key.nil? || updated_contents.nil?
        # Don't set content_stream separately if it can be done by setting the content during create
        result << {:message => :save_content_stream, :parameters => [updated_contents]}
      end

      result
    end

    def self_or_new(entry)
      if entry.nil?
        nil
      elsif entry.xpath("cra:object/c:properties/c:propertyId[@propertyDefinitionId = 'cmis:objectId']/c:value", NS::COMBINED).text == id
        self
      else
        ActiveCMIS::Object.from_atom_entry(repository, entry)
      end
    end

    def create_url
      if f = parent_folders.first
        url = f.items.url
        if self.class.versionable # Necessary in OpenCMIS at least
          url
        else
          Internal::Utils.append_parameters(url, "versioningState" => "none")
        end
      else
        raise "Creating an unfiled document is not supported by CMIS"
        # Can't create documents that are unfiled
      end
    end

    def save_content_stream(stream)
      raise "no content to save" if stream.nil?

      # put to link with rel 'edit-media' if it's there
      # NOTE: cmislib uses the src link of atom:content instead, that might be correct
      edit_links = Internal::Utils.extract_links(data, "edit-media")
      if edit_links.length == 1
        link = edit_links.first
      elsif edit_links.empty?
        raise "No edit-media link, can't save content"
      else
        raise "Too many edit-media links, don't know how to choose"
      end
      data = stream[:data] || File.open(stream[:file])
      content_type = stream[:mime_type] || "application/octet-stream"

      url = Internal::Utils.append_parameters(link, "overwrite" => stream[:overwrite]) if stream.has_key?(:overwrite)
      conn.put(url, data, "Content-Type" => content_type)
      self
    end
  end
end
