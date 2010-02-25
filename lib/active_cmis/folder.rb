module ActiveCMIS
  class Folder < ActiveCMIS::Object
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
