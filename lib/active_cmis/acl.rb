module ActiveCMIS
  # ACLs belong to a document and have no identity of their own
  class Acl
    include Internal::Caching

    attr_reader :document, :repository

    def initialize(repository, document, link, _data = nil)
      @repository = repository
      @document   = document
      @self_link  = case link
                    when URI; link
                    else URI(link)
                    end
      @data = _data if _data
    end

    # Returns an array with all Aclentries.
    #
    def permissions
      data.xpath("c:permission", NS::COMBINED).map do |permit|
        principal      = nil
        permissions    = []
        direct         = false
        permit.children.each do |child|
          next unless child.namespace && child.namespace.href == NS::CMIS_CORE

          case child.name
          when "principal"
            child.children.map do |n|
              next unless n.namespace && n.namespace.href == NS::CMIS_CORE

              if n.name == "principalId" && principal.nil?
                principal = convert_principal(n.text)
              end
            end
          when "permission"
            permissions << child.text
          when "direct"
            direct = AtomicType::Boolean.xml_to_bool(child.text)
          end
        end
        AclEntry.new(principal, permissions, direct)
      end
    end
    cache :permissions

    # An indicator that the ACL fully describes the permissions for this object.
    # This means that there are no other security constraints.
    def exact
      value = data.xpath("c:exact", NS::COMBINED)
      if value.empty?
        false
      elsif value.length == 1
        AtomicType::Boolean.xml_to_bool(value.first.text)
      else
        raise "Unexpected multiplicity of exactness ACL"
      end
    end
    cache :exact

    # :section: Updating ACLs
    # The effect on documents other than the one this ACL belongs to depends
    # on the repository.
    #
    # The user can be "cmis:user" to indicate the currently logged in user
    # For :anonymous and :world you can use both the the active_cmis symbol
    # or the name used by the CMIS repository

    def grant_permission(user, *new_permissions)
      principal = convert_principal(user)

      relevant = permissions.select {|p| p.principal == principal && p.direct?}
      if relevant = relevant.first
        permissions.delete relevant
        new_permissions.concat(relevant.permissions)
      end

      permissions << AclEntry.new(principal, new_permissions, true)
    end

    # Note: it is untested how this works together with direct == false
    def revoke_permission(user, *new_permissions)
      principal = convert_principal(user)

      keep = permissions.reject {|p| p.principal == principal && p.permissions.any? {|t| new_permissions.include? t} }

      relevant = permissions.select {|p| p.principal == principal && p.permissions.any? {|t| new_permissions.include? t} }
      changed  = relevant.map {|p| AclEntry.new(principal, p.permissions - new_permissions, p.direct?) }

      @permissions = keep + changed
    end

    # Note: it is untested how this works together with direct == false
    def revoke_all_permissions(user)
      principal = convert_principal(user)
      permissions.reject! {|p| p.principal == principal}
    end

    # Needed to actually execute changes on the server
    def apply
      body = Nokogiri::XML::Builder.new do |xml|
        xml.acl("xmlns" => NS::CMIS_CORE) do
          permissions.each do |permission|
            xml.permission do
              xml.principal { xml.principalId { convert_principal(permission.principal) }}
              xml.direct    { permission.direct? }
              permission.each do |permit|
                xml.permission { permit }
              end
            end
          end
        end
      end
      conn.put(self_link("onlyBasicPermissions" => false), body)
      reload
    end

    private
    def self_link(options = {})
      Internal::Utils.add_parameters(@self_link, options)
    end

    def conn
      repository.conn
    end

    def data
      conn.get_xml(self_link).xpath("c:acl", NS::COMBINED)
    end
    cache :data

    def anonymous_user
      repository.anonymous_user
    end
    def world_user
      repository.world_user
    end

    def convert_principal(principal)
      case principal
      when :anonymous
        anonymous_user
      when :world
        world
      when anonymous_user
        :anonymous
      when world_user
        :world
      else
        principal
      end
    end

  end
end
