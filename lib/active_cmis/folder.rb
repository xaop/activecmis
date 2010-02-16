module ActiveCMIS
  class Folder < ActiveCMIS::Object
    # Depending on the repository there can be more than 1 parent folder
    #
    # FIXME: This method should also work for document, and depending on the repository for Policy,
    # it should not work for relationships
    # Solution?: make base types repository dependent, have this method in a mixin Fileable
    # Actual inclusion could be done based on repository configuration
    # Alternative solution: Define on ActiveCMS::Object
    def parent_folders
      @parent ||= begin
                    query = "at:entry/at:link[@rel = 'up' and @type = 'application/atom+xml;type=%s']/@href"
                    parent_feed = @data.xpath(query % 'feed', NS::COMBINED).to_s
                    if parent_feed && parent_feed != ""
                      feed = Nokogiri.parse(@conn.get(parent_feed))
                      feed.xpath('at:feed', NS::COMBINED).map do |e|
                        puts e.to_s
                        ActiveCMIS::Object.from_atom_entry(@conn, e)
                      end
                    else
                      parent_entry = @data.xpath(query % 'entry', NS::COMBINED).to_s
                      if parent_entry && parent_entry != ""
                        e = Nokogiri.parse(@conn.get(parent_feed)).xpath('at:entry', NS::COMBINED)
                        [ActiveCMIS::Object.from_atom_entry(@conn, e)]
                      else
                        []
                      end
                    end
                  end
    end

    # All folders directly filed in this folder
    def child_folders
      
    end

    # All documents directly filed in this folder
    def child_documents
    end

    # All policies that are filed in this folder
    def child_policies
      [] # TODO: implement
    end

    # Sum of sub_folders, child_documents and child_policies
    def all_children
    end
  end
end
