module ActiveCMIS
  class Type
    def initialize(conn, data)
      @conn = conn
      @data = data
    end

    def inspect
      "<#ActiveCMIS::Type #{key}>"
    end

    def key
      @key ||= @data.xpath("cra:type/c:id", NS::COMBINED).text
    end
  end
end
