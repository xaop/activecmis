module ActiveCMIS
  module Internal
    module Caching
      def self.included(cl)
        cl.extend ClassMethods
      end

      module ClassMethods
        def cache(*names)
          (@cached_methods ||= []).concat(names).uniq!
          names.each do |name|
            alias_method("#{name}__uncached", name)
            class_eval <<-RUBY, __FILE__, __LINE__
              def #{name}(*a, &b)
                if defined? @#{name}
                  @#{name}
                else
                  @#{name} = #{name}__uncached(*a, &b)
                end
              end
              def reload
                #{@cached_methods.inspect}.map do |method|
                  :"@\#{method}"
                end.select do |iv|
                  instance_variable_defined? iv
                end.each do |iv|
                  remove_instance_variable iv
                end + (defined?(super) ? super : [])
              end
            RUBY
          end
        end
      end
    end
  end
end
