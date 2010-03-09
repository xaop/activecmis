module ActiveCMIS
  class Folder < ActiveCMIS::Object
    def items
      if url = child_collection_url
        feed = conn.get_xml(url)
        feed.xpath('at:feed/at:entry', NS::COMBINED).map do |e|
          ActiveCMIS::Object.from_atom_entry(repository, e)
        end
        # FIXME: handle next links
      else
        []
      end
    end
    cache :items

    def child_collection_url
      query = "at:link[@rel = 'down' and @type = 'application/atom+xml;type=feed']/@href"
      item_feed = data.xpath(query, NS::COMBINED)
      unless item_feed.empty?
        item_feed.to_s
      end
    end
  end
end
