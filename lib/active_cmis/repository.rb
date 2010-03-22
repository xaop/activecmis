module ActiveCMIS
  class Repository
    def initialize(connection, initial_data) #:nodoc:
      @conn = connection
      @data = initial_data
    end

    # Use authentication to access the CMIS repository
    #
    # e.g.: repo.authenticate(:basic, "username", "password")
    def authenticate(method, *params)
      conn.authenticate(method, *params)
    end

    def key
      @key ||= data.xpath('cra:repositoryInfo/c:repositoryId', NS::COMBINED).text
    end

    def inspect
      "<#ActiveCMIS::Repository #{key}>"
    end

    def cmis_version
      # NOTE: we might want to "version" our xml namespaces depending on the CMIS version
      # If we do that we need to make this method capable of not using the predefined namespaces
      #
      # On the other hand breaking the XML namespace is probably going to break other applications too so the might not change them even when the spec is updated
      @cmis_version ||= data.xpath("cra:repositoryInfo/c:cmisVersionSupported", NS::COMBINED).text
    end

    # default parameters: renditionFilter => "*", includeAllowableActions => true, includeACL => true
    def object_by_id(id, parameters = {"renditionFilter" => "*", "includeAllowableActions" => "true", "includeACL" => true})
      ActiveCMIS::Object.from_parameters(self, parameters.merge("id" => id))
    end

    def object_by_id_url(parameters)
      template = pick_template("objectbyid")
      raise "Repository does not define required URI-template 'objectbyid'" unless template
      url = fill_in_template(template, parameters)
    end

    def type_by_id(id)
      @type_by_id ||= {}
      if result = @type_by_id[id]
        result
      else
        template = pick_template("typebyid")
        raise "Repository does not define required URI-template 'typebyid'" unless template
        url = fill_in_template(template, "id" => id)

        @type_by_id[id] = Type.create(conn, self, conn.get_atom_entry(url))
      end
    end

    %w[root query checkedout unfiled].each do |coll_name|
      define_method coll_name do
        iv = :"@#{coll_name}"
        if instance_variable_defined?(iv)
          instance_variable_get(iv)
        else
          href = data.xpath("app:collection[cra:collectionType[child::text() = '#{coll_name}']]/@href", NS::COMBINED)
          if href.first
            result = Collection.new(self, href.first)
          else
            result = nil
          end
          instance_variable_set(iv, result)
        end
      end
    end

    def base_types
      @base_types ||= begin
                        query = "app:collection[cra:collectionType[child::text() = 'types']]/@href"
                        href = data.xpath(query, NS::COMBINED)
                        if href.first
                          url = href.first.text
                          Collection.new(self, url) do |entry|
                            id = entry.xpath("cra:type/c:id", NS::COMBINED).text
                            type_by_id id
                          end
                        else
                          raise "Repository has no types collection, this is strange and wrong"
                        end
                      end
    end

    def types
      @types ||= base_types.map do |t|
        t.all_subtypes
      end.flatten
    end

    # Returns a collection with the changes since the given changeLogToken.
    #
    # Completely uncached
    #
    # Parameters: a Hash containing parameters, valid keys are:
    # - filter
    # - changeLogToken
    # - maxItems
    # - includeACL
    # - includePolicyIds
    # - includeProperties
    #
    # All parameters are optional
    def changes(parameters = {})
      query = "at:link[@rel = '#{Rel[cmis_version][:changes]}']/@href"
      link = data.xpath(query, NS::COMBINED)
      if link = link.first
        link = Internal::Utils.append_parameters(link.to_s, parameters)
        Collection.new(self, link)
      end
    end

    def root_folder
      @root_folder ||= object_by_id(data.xpath("cra:repositoryInfo/c:rootFolderId", NS::COMBINED).text)
    end

    def conn
      @conn ||= Internal::Connection.new
    end

    # :section: Capabilities

    # A hash containing all capabilities of the repository
    def capabilities
      @capabilities ||= begin
                          capa = {}
                          data.xpath("cra:repositoryInfo/c:capabilities/*", NS::COMBINED).map do |node|
                            # FIXME: conversion should be based on knowledge about data model + transforming bool code should not be duplicated
                            capa[node.name.sub("capability", "")] = case t = node.text
                                              when "true", "1"; true
                                              when "false", "0"; false
                                              else t
                                              end
                          end
                          capa
                        end
    end

    # Responds with true if Private Working Copies are updateable, fals otherwise
    # (if false the PWC object can only be updated during the checkin)
    def pwc_updatable?
      capabilities["PWCUpdatable"]
    end

    # Responds with true if different versions of the same document can
    # be filed in different folders
    def version_specific_filing?
      capabilities["VersionSpecificFiling"]
    end

    # :section: ACLs
    # The code in this section is used to describe the ACL configuration of the repository.
    # This includes listing the possible values for acl permissions and listing which principal names are used to describe :anonymous and :world

    # returns true if ACLs can at least be viewed
    def acls_readable?
      ["manage", "discover"].include? capabilities["ACL"]
    end

    def anonymous_user
      if acls_readable?
        data.xpath('cra:repositoryInfo/c:principalAnonymous', NS::COMBINED).text
      end
    end

    def world_user
      if acls_readable?
        data.xpath('cra:repositoryInfo/c:principalAnyone', NS::COMBINED).text
      end
    end

    private
    attr_reader :data

    def pick_template(name, options = {})
      # FIXME: we can have more than 1 template with differing media types
      #        I'm not sure how to pick the right one in the most generic/portable way though
      #        So for the moment we pick the 1st and hope for the best
      #        Options are ignored for the moment
      data.xpath("n:uritemplate[n:type[child::text() = '#{name}']][1]/n:template", "n" => NS::CMIS_REST).text
    end


    # The type parameter should contain the type of the uri-template
    #
    # The keys of the values hash should be strings,
    # if a key is not in the hash it is presumed to be equal to the empty string
    # The values will be percent-encoded in the fill_in_template method
    # If a given key is not present in the template it will be ignored silently
    #
    # e.g. fill_in_template("objectbyid", "id" => "@root@", "includeACL" => true)
    #      -> 'http://example.org/repo/%40root%40?includeRelationships&includeACL=true'
    def fill_in_template(template, values)
      result = template.gsub /\{([^}]+)\}/ do |match|
        Internal::Utils.percent_encode(values[$1].to_s)
      end
    end
  end
end
