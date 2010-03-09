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
            data = content.to_xml # FIXME: this may not preserve whitespace
          else
            data = data.unpack("m*").first
          end
          ActiveCMIS::Rendition.new(repository, "data" => data, "type" => content["type"])
        end
      elsif content = data.xpath("cra:content", NS::COMBINED).first
        content.children.each do |node|
          next unless node.namespace and node.namespace.href == NS::CMIS_REST
          data = node.text if node.name == "base64"
          type = node.text if node.name == "mediaType"
        end
        data = data.unpack("m*").first
        ActiveCMIS::Rendition.new(repository, "data" => data, "type" => type)
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

    # NOTE: Not implemented yet
    # options for content can be :file => filename or :data => binary_data
    # :overwrite defaults to true, if false the content of the document won't be overwritten
    # :mime_type => mime_type
    #
    # This returns the document with the new content, this may be a new version in the version series and as such may not be equal to self
    def set_content_stream(mime_type, options)
      # put to link with rel 'edit-media'
    end

    # :section: Versioning
    # Documents can be versionable, other types of objects are never versionable

    # Returns all documents in the version series of this document.
    # Uses self to represent the version of this document
    def versions
      link = data.xpath("at:link[@rel = 'version-history']/@href", NS::COMBINED)
      if link.first
        feed = conn.get_xml(link.first.text)
        entries = feed.xpath("at:feed/at:entry", NS::COMBINED)
        entries.map do |entry|
          self_or_new(entry)
        end
      else
        # The document is not versionable
        [self]
      end
    end

    # Returns self if this is the latest version
    # Note: There will allways be a latest version in a version series
    def latest_version
      link = data.xpath("at:link[@rel = 'current-version']/@href", NS::COMBINED)
      if link.first
        entry = conn.get_atom_entry(link.first.text)
        self_or_new(entry)
      else
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
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.entry(NS::COMBINED) {
          xml.parent.namespace = xml.parent.namespace_definitions.detect {|ns| ns.prefix == "at"}
          xml["at"].author {
            xml["at"].name conn.user # FIXME: find reliable way to set author?
          }
          xml["cra"].object {
            xml["c"].properties {
              xml["c"].propertyId("propertyDefinitionId" => "cmis:objectId") {
                xml["c"].value id
              }
            }
          }
        }
      end
      body = builder.to_xml
      response = conn.post(repository.checkedout.url, body)
    end

    # This action may not be permitted (query allowable_actions to see whether it is permitted)
    def cancel_checkout
      conn.delete(self_link)
    end

    # You can specify whether the new version should be major (defaults to true)
    # You can optionally give a list of attributes that need to be set.
    #
    # This operation exists only for Private Working Copies
    # If the operation succeeds this object becomes the latest in the version series
    def checkin(major = true, updated_attributes = {}, checkin_comment = "")
      self.updated_attributes.merge(updated_attributes.keys)
      self.attributes.merge(updated_attributes)
      response = put(true, major, checkin_comment)
      # Check response body for updated object id and updated location header
    end

    private
    def escape_parameter(url)
      control = "\x00-\x1F\x7F"
      space   = " "
      delims  = "<>#%\""
      unwise  = '{}|\\\\^\[\]`'
      query   = ";/?:@&=+,$"
      URI.escape(url, /[#{control+space+delims+unwise+query}]/o)
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
  end
end
