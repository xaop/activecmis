module ActiveCMIS
  class Collection
    include Internal::Caching
    include ::Enumerable

    attr_reader :repository, :url

    def initialize(repository, url)
      @repository = repository
      @url = URI.parse(url)

      @next = @url
      @elements = []
      @pages = []
    end

    def length
      receive_page
      if @length.nil?
        i = 1
        while @next
          receive_page
          i += 1
        end
        @elements.length
      else
        @length
      end
    end
    alias size length
    cache :length

    # FIXME: can be more efficient than this
    def empty?
      length == 0
    end

    def to_a
      while @next
        receive_page
      end
      @elements
    end

    def at(index)
      if index < @elements.length
        @elements[index]
      elsif index > length
        nil
      else
        while @next && @elements.length < index
          receive_page
        end
        @elements[index]
      end
    end

    def [](index, length = nil)
      if length
        index = sanitize_index(index)
        range_get(index, index + length - 1)
      elsif Range === index
        range_get(sanitize_index(index.begin), index.exclude_end? ? sanitize_index(index.end) - 1 : sanitize_index(index.end))
      else
        at(index)
      end
    end
    alias slice []

    def each
      length.times { |i| yield self[i] }
    end

    def reverse_each
      (length - 1).downto(0) { |i| yield self[i] }
    end

    def inspect
      "#<Collection %s>" % url
    end

    def to_s
      to_a.to_s
    end

    def uniq
      to_a.uniq
    end

    def sort
      to_a.sort
    end

    def reverse
      to_a.reverse
    end

    def reload
      super
      @pages = []
      @elements = []
    end

    private

    def sanitize_index(index)
      index < 0 ? size + index : index
    end

    def range_get(from, to)
      (from..to).map { |i| at(i) }
    end

    def receive_page(i = nil)
      i ||= @pages.length
      @pages[i] ||= begin
                      return nil unless @next
                      xml = conn.get_xml(@next)

                      @next = xml.xpath("at:link[@rel = 'next']", NS::COMBINED).first
                      @next = @next.nil? ? nil : @next.text

                      new_elements = xml.xpath('at:feed/at:entry', NS::COMBINED).map do |e|
                        ActiveCMIS::Object.from_atom_entry(repository, e)
                      end
                      @elements.concat(new_elements)

                      num_items = xml.xpath("cra:numItems", NS::COMBINED).first
                      @length ||= num_items.text.to_i if num_items # We could also test on the repository

                      xml
                    end
    end

    def conn
      repository.conn
    end

  end
end
