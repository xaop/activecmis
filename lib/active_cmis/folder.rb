module ActiveCMIS
  class Folder < ActiveCMIS::Object
    # Depending on the repository there can be more than 1 parent folder
    #
    # FIXME: This method should also work for document, and depending on the repository for Policy,
    # it should not work for relationships
    def parent_folders
      query = "at:link[@rel = 'up' and @type = 'application/atom+xml;type=%s']/@href"
      parent_feed = data.xpath(query % 'feed', NS::COMBINED)
      unless parent_feed.empty?
        feed = conn.get_xml(parent_feed.to_s)
        feed.xpath('at:feed/at:entry', NS::COMBINED).map do |e|
          ActiveCMIS::Object.from_atom_entry(repository, e)
        end
      else
        parent_entry = @data.xpath(query % 'entry', NS::COMBINED)
        unless parent_entry.empty?
          e = conn.get_atom_entry(parent_feed.to_s)
          [ActiveCMIS::Object.from_atom_entry(repository, e)]
        else
          []
        end
      end
    end
    cache :parent_folders

    def items
      query = "at:link[@rel = 'down' and @type = 'application/atom+xml;type=feed']/@href"
      item_feed = data.xpath(query % 'feed', NS::COMBINED)
      unless item_feed.empty?
        feed = conn.get_xml(item_feed.to_s)
        feed.xpath('at:feed/at:entry', NS::COMBINED).map do |e|
          ActiveCMIS::Object.from_atom_entry(repository, e)
        end
      end
    end
    cache :items
  end
end
