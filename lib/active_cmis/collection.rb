module ActiveCMIS
  class Collection
    attr_reader :repository, :url

    def initialize(repository, url)
      @repository = repository
      @url = URI.parse(url)
    end
  end
end
