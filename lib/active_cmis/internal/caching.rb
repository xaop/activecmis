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
            class_eval <<-RUBY, __FILE__, __LINE__+1
              if private_method_defined? :"#{name}"
                private_method = true
              end
              def #{name}(*a, &b)
                if defined? @#{name}
                  @#{name}
                else
                  @#{name} = #{name}__uncached(*a, &b)
                end
              end
              if private_method
                private :"#{name}__uncached"
                private :"#{name}"
              end
            RUBY
          end
          reloadable
        end

        def cached_reader(*names)
          (@cached_methods ||= []).concat(names).uniq!
          names.each do |name|
            define_method "#{name}" do
              if instance_variable_defined? "@#{name}"
                instance_variable_get("@#{name}")
              else
                load_from_data # FIXME: make flexible?
                instance_variable_get("@#{name}")
              end
            end
          end
          reloadable
        end

        private
        def reloadable
          class_eval <<-RUBY, __FILE__, __LINE__
            def __reload
              #{@cached_methods.inspect}.map do |method|
                :"@\#{method}"
              end.select do |iv|
                instance_variable_defined? iv
              end.each do |iv|
                remove_instance_variable iv
              end + (defined?(super) ? super : [])
            end
            private :__reload
          RUBY
          unless instance_methods.include? "reload"
            class_eval <<-RUBY, __FILE__, __LINE__
              def reload
                __reload
              end
            RUBY
          end
        end
      end
    end
  end
end
