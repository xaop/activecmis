module ActiveCMIS
  class Folder < ActiveCMIS::Object
    def items
      query = "at:link[@rel = 'down' and @type = 'application/atom+xml;type=feed']/@href"
      item_feed = data.xpath(query, NS::COMBINED)
      raise "No child feed link for folder" unless item_feed
      Collection.new(repository, item_feed.to_s)
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
