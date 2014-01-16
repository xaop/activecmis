module ActiveCMIS
  class Document < ActiveCMIS::Object
    # Returns an ActiveCMIS::Rendition to the content stream or nil if there is none
    # @return [Rendition]
    def content_stream
      if content = data.xpath("at:content", NS::COMBINED).first
        if content['src']
          ActiveCMIS::Rendition.new(repository, self, "href" => content['src'], "type" => content["type"])
        else
          if content['type'] =~ /\+xml$/
            content_data = content.to_xml # FIXME: this may not preserve whitespace
          else
            content_data = data.unpack("m*").first
          end
          ActiveCMIS::Rendition.new(repository, self, "data" => content_data, "type" => content["type"])
        end
      elsif content = data.xpath("cra:content", NS::COMBINED).first
        content.children.each do |node|
          next unless node.namespace and node.namespace.href == NS::CMIS_REST
          content_data = node.text if node.name == "base64"
          content_type = node.text if node.name == "mediaType"
        end
        data = content_data.unpack("m*").first
        ActiveCMIS::Rendition.new(repository, self, "data" => content_data, "type" => content_type)
      end
    end
    cache :content_stream

    # Will reload if renditionFilter was not set or cmis:none, but not in other circumstances
    # @return [Array<Rendition>]
    def renditions
      filter = used_parameters["renditionFilter"]
      if filter.nil? || filter == "cmis:none"
        reload
      end

      links = data.xpath("at:link[@rel = 'alternate']", NS::COMBINED)
      links.map do |link|
        ActiveCMIS::Rendition.new(repository, self, link)
      end
    end
    cache :renditions

    # Sets new content to be uploaded, does not alter values you will get from content_stream (for the moment)
    # @param [Hash] options A hash containing exactly one of :file or :data
    # @option options [String] :file The name of a file to upload
    # @option options [#read] :data Data you want to upload (if #length is defined it should give the total length that can be read)
    # @option options [Boolean] :overwrite (true) Whether the contents should be overwritten (ignored in case of checkin)
    # @option options [String] :mime_type
    #
    # @return [void]
    def set_content_stream(options)
      if key.nil?
        if self.class.content_stream_allowed == "notallowed"
          raise Error::StreamNotSupported.new("Documents of this type can't have content")
        end
      else
        updatability = repository.capabilities["ContentStreamUpdatability"]
        if updatability == "none"
          raise Error::NotSupported.new("Content can't be updated in this repository")
        elsif updatability == "pwconly" && !working_copy?
          raise Error::Constraint.new("Content can only be updated for working copies in this repository")
        end
      end
      @updated_contents = options
    end

    # Sets versioning state.
    # Only possible on new documents, or PWC documents
    #
    # @param ["major", "minor", "none", "checkedout"] state A string of the desired versioning state
    #
    # @return [void]
    def set_versioning_state(state)
      raise Error::Constraint.new("Can only set a different version state on PWC documents, or unsaved new documents") unless key.nil? || working_copy?
      raise ArgumentError, "You must pass a String" unless state.is_a?(String)
      if key.nil?
        possible_values = %w[major minor none checkedout]
      else
        possible_values = %w[major minor]
      end
      raise ArgumentError, "Given state is invalid. Possible values are #{possible_values.join(", ")}" unless possible_values.include?(state)

      @versioning_state = state
    end

    # Returns all documents in the version series of this document.
    # Uses self to represent the version of this document
    # @return [Collection<Document>, Array(self)]
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
    # @return [Document]
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
    # @return [Document]
    def working_copy
      link = data.xpath("at:link[@rel = 'working-copy']/@href", NS::COMBINED)
      if link.first
        entry = conn.get_atom_entry(link.first.text)
        self_or_new(entry)
      else
        nil
      end
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
      return false if key.nil?

      # NOTE: This may not be a sufficient condition, but according to the spec it should be
      !data.xpath("at:link[@rel = 'via']", NS::COMBINED).empty?
    end

    # Returns information about the checked out status of this document
    #
    # @return [Hash,nil] Keys are :by for the owner of the PWC and :id for the CMIS ID, both can be unset according to the spec
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
    # @return [Document] The checked out version of this document
    def checkout
      body = render_atom_entry(self.class.attributes.reject {|k,v| k != "cmis:objectId"})

      response = conn.post_response(repository.checkedout.url, body)
      if 200 <= response.code.to_i && response.code.to_i < 300
        entry = Nokogiri::XML.parse(response.body, nil, nil, Nokogiri::XML::ParseOptions::STRICT).xpath("/at:entry", NS::COMBINED)
        result = self_or_new(entry)
        if result.working_copy? # Work around a bug in OpenCMIS where result returned is the version checked out not the PWC
          result
        else
          conn.logger.warn "Repository did not return working copy for checkout operation"
          result.working_copy
        end
      else
        raise response.body
      end
    end

    # This action may not be permitted (query allowable_actions to see whether it is permitted)
    # @return [void]
    def cancel_checkout
      if !self.class.versionable
        raise Error::Constraint.new("Object is not versionable, can't cancel checkout")
      elsif working_copy?
        conn.delete(self_link)
      else
        raise Error::InvalidArgument.new("Not a working copy")
      end
    end

    # @overload checkin(major, comment = "", updated_attributes = {})
    #   Check in the private working copy. Raises a constraint error when the
    #   document is not a working copy
    #
    #   @param [Boolean] major Whether the document will be checked in as a major version
    #   @param [String] comment An optional comment to use when creating the new version
    #   @param [Hash] updated_attributes A hash with updated attributes
    #   @return [Document] The final version that results from the checkin
    # @overload checkin(comment = "", updated_attributes = {})
    #   Check in the private working copy. Raises a constraint error when the
    #   document is not a working copy
    #   The version will be the version set by set_versioning_state (default is
    #   a major version)
    #
    #   @param [String] comment An optional comment to use when creating the new version
    #   @param [Hash] updated_attributes A hash with updated attributes
    #   @return [Document] The final version that results from the checkin
    # @overload checkin(updated_attributes = {})
    #   Check in the private working copy with an empty message.
    #   Raises a constraint error when the document is not a working copy
    #   The version will be the version set by set_versioning_state (default is
    #   a major version)
    #
    #   @param [Hash] updated_attributes A hash with updated attributes
    #   @return [Document] The final version that results from the checkin
    def checkin(*options)
      if options.length > 3
        raise ArgumentError, "Too many arguments for checkin"
      else
        major, comment, updated_attributes = *options
        if TrueClass === major or FalseClass === major
          # Nothing changes: only defaults need to be filled in (if necessary)
        elsif String === major
          updated_attributes = comment
          comment = major
          # major will be true if: @versioning_state == "major", or if it's not set
          major = @versioning_state != "minor"
        elsif Hash === major
          updated_attributes = major
          major = @versioning_state != "minor"
        end
        comment ||= ""
        updated_attributes ||= {}
      end

      if working_copy?
        update(updated_attributes)
        result = self
        updated_aspects([true, major, comment]).each do |hash|
          result = result.send(hash[:message], *hash[:parameters])
        end
        @versioning_state = nil
        result
      else
        raise Error::Constraint, "Not a working copy"
      end
    end

    # @return [void]
    def reload
      @updated_contents = nil
      super
    end

    private
    attr_reader :updated_contents

    def render_atom_entry(properties = self.class.attributes, attributes = self.attributes, options = {})
      super(properties, attributes, options) do |entry|
        if updated_contents && (options[:create] || options[:checkin])
          entry["cra"].content do
            entry["cra"].mediatype(updated_contents[:mime_type] || "application/binary")
            data = updated_contents[:data] || File.read(updated_contents[:file])
            entry["cra"].base64 [data].pack("m")
          end
        end
        if block_given?
          yield(entry)
        end
      end
    end


    def updated_aspects(checkin = nil)
      if working_copy? && !(checkin || repository.pwc_updatable?)
        raise Error::NotSupported.new("Updating a PWC without checking in is not supported by repository")
      end
      unless working_copy? || checkin.nil?
        raise Error::NotSupported.new("Can't check in when not checked out")
      end

      result = super

      if !key.nil? && !updated_contents.nil?
        if checkin
          # Update the content stream before checking in
          result.unshift(:message => :save_content_stream, :parameters => [updated_contents])
        else
          # TODO: check that the content stream is updateable
          result << {:message => :save_content_stream, :parameters => [updated_contents]}
        end
      end

      result
    end

    def self_or_new(entry)
      if entry.nil?
        nil
      elsif entry.xpath("cra:object/c:properties/c:propertyId[@propertyDefinitionId = 'cmis:objectId']/c:value", NS::COMBINED).text == id
        reload
        @data = entry
        self
      else
        ActiveCMIS::Object.from_atom_entry(repository, entry)
      end
    end

    def create_url
      if f = parent_folders.first
        url = f.items.url
        Internal::Utils.append_parameters(url, "versioningState" => (self.class.versionable ? (@versioning_state || "major") : "none"))
      else
        raise Error::NotSupported.new("Creating an unfiled document is not supported by CMIS")
        # Can't create documents that are unfiled, CMIS does not support it (note this means exceptions should not actually be NotSupported)
      end
    end

    def save_content_stream(stream)
      # Should never occur (is private method)
      raise "no content to save" if stream.nil?

      # put to link with rel 'edit-media' if it's there
      # NOTE: cmislib uses the src link of atom:content instead, that might be correct
      edit_links = Internal::Utils.extract_links(data, "edit-media")
      if edit_links.length == 1
        link = edit_links.first
      elsif edit_links.empty?
        raise Error.new("No edit-media link, can't save content")
      else
        raise Error.new("Too many edit-media links, don't know how to choose")
      end
      data = stream[:data] || File.open(stream[:file])
      content_type = stream[:mime_type] || "application/octet-stream"

      if stream.has_key?(:overwrite)
        url = Internal::Utils.append_parameters(link, "overwrite" => stream[:overwrite])
      else
        url = link
      end
      conn.put(url, data, "Content-Type" => content_type)
      self
    end
  end
end
