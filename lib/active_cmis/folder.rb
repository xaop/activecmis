module ActiveCMIS
  class Folder < ActiveCMIS::Object
    # Returns a collection of all items contained in this folder (1 level deep)
    # @return [Collection<Document,Folder,Policy>]
    def items
      item_feed = Internal::Utils.extract_links(data, 'down', 'application/atom+xml','type' => 'feed')
      raise "No child feed link for folder" if item_feed.empty?
      Collection.new(repository, item_feed.first)
    end
    cache :items

    private
    def create_url
      if f = parent_folders.first
        f.items.url
      else
        raise "Not possible"
      end
    end
  end
end
