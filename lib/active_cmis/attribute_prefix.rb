module ActiveCMIS
  class AttributePrefix
    attr_reader :object, :prefix

    def initialize(object, prefix)
      @object = object
      @prefix = prefix
    end

    def method_missing(method, *parameters)
      string = method.to_s
      if string[-1] == ?=
        assignment = true
        string = string[0..-2]
      end
      attribute = "#{prefix}:#{string}"
      if object.class.attributes.keys.include? attribute
        if assignment
          object.update(attribute => parameters.first)
        else
          object.attribute(attribute)
        end
      else
        # TODO: perhaps here we should try to look a bit further to see if there is a second :
        super
      end
    end
  end
end
