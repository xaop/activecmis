module ActiveCMIS
  class Relationship < ::ActiveCMIS::Object
    # :section: Fileable
    # None of the following methods do anything useful

    # Return [], a relationship is not fileable
    def parent_folders
      []
    end

    private
    def create_url
      raise "not yet"
      # Resource collection of parent or child?
    end
  end
end
