module ActiveCMIS
  class AclEntry
    def initialize(principal, permissions, direct)
      @principal = principal.freeze
      @permissions = permissions.freeze
      @permissions.each {|p| p.freeze}
      @direct = direct
    end


    # Normal users are represented with a string, a non-logged in user is known
    # as :anonymous, the principal :world represents the group of all logged in
    # users.
    #
    # Permissions is a frozen array of strings
    attr_reader :principal, :permissions

    def direct?
      @direct
    end
  end
end
