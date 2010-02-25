module ActiveCMIS
  class Relationship < ::ActiveCMIS::Object
    # :section: Fileable
    # None of the following methods do anything useful

    # Return [], a relationship is not fileable
    def parent_folders
      []
    end
  end
end
