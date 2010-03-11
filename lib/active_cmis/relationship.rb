module ActiveCMIS
  class Relationship < ::ActiveCMIS::Object
    def source
      Internal::Utils.string_or_id_to_object(attribute("cmis:sourceId"))
    end
    cache :source

    def target
      Internal::Utils.string_or_id_to_object(attribute("cmis:targetId"))
    end
    cache :target

    def delete
      conn.delete(self_link)
    end

    def update(updates = {})
      super
      # Potentially necessary if repositories support it
      # Probably not though
      if source = updates["cmis:sourceId"]
        remove_instance_variable "@source"
      end
      if updates["cmis:targetId"]
        remove_instance_variable "@target"
      end
    end

    # :section: Fileable
    # None of the following methods do anything useful

    # Return [], a relationship is not fileable
    def parent_folders
      []
    end

    private
    def create_url
      source.source_relations.url
    end
  end
end
