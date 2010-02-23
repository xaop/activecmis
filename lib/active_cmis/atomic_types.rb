module ActiveCMIS
  module AtomicType
    class String
      attr_reader :max_length
      def initialize(max_length)
        @max_length = max_length
      end

      def to_s
        "String"
      end

      def cmis2rb(value)
        value.text
      end
      def rb2cmis(xml, value)
        v = value.to_s
        if max_length && v.length > max_length
          raise "String representation is longer than maximum (max: #{max_length}, string: \n'\n#{v}\n')\n"
        end
        xml["c"].value v
      end
    end

    # Precision is ignored?
    class Decimal
      attr_reader :precision, :min_value, :max_value
      def initialize(precision, min_value, max_value)
        @precision, @min_value, @max_value = precision, min_value, max_value
      end

      def to_s
        "Decimal"
      end

      def cmis2rb(value)
        value.text.to_f
      end
      def rb2cmis(xml, value)
        v = value.to_f
        if (min_value && v < min_value) || (max_value && v > max_value)
          raise "OutOfBounds: #{v} should be between #{min_value} and #{max_value}"
        end
        xml["c"].value("%f" % v)
      end
    end

    class Integer
      attr_reader :min_value, :max_value
      def initialize(min_value, max_value)
        @min_value, @max_value = min_value, max_value
      end

      def to_s
        "Integer"
      end

      def cmis2rb(value)
        value.text.to_i
      end
      def rb2cmis(xml, value)
        v = value.to_int
        if (min_value && v < min_value) || (max_value && v > max_value)
          raise "OutOfBounds: #{v} should be between #{min_value} and #{max_value}"
        end
        xml["c"].value("%i" % v)
      end
    end

    class DateTime
      attr_reader :resolution

      @instances ||= {}
      def self.new(precision)
        raise ArgumentError.new("Got precision = #{precision.inspect}") unless [YEAR, DATE, TIME].include? precision.to_s.downcase
        @instances[precision] ||= super
      end

      def to_s
        "DateTime"
      end

      def initialize(resolution)
        @resolution = resolution
      end
      YEAR = "year"
      DATE = "date"
      TIME = "time"

      def cmis2rb(value)
        case @resolution
        when YEAR, DATE; ::DateTime.parse(value.text).to_date
        when TIME; ::DateTime.parse(value.text)
        end
      end
      def rb2cmis(xml, value)
        # FIXME: respect resolution
        p value
        xml["c"].value(value.strftime("%Y-%m-%dT%H:%M:%S%Z"))
      end
    end

    class Singleton
      def self.new
        @singleton ||= super
      end
    end

    class Boolean < Singleton
      def self.xml_to_bool(value)
        case value
        when "true", "1"; true
        when "false", "0"; false
        else raise ActiveCMIS::Error.new("An invalid boolean was found in CMIS")
        end
      end

      def to_s
        "Boolean"
      end

      def cmis2rb(value)
        self.class.xml_to_bool(value.text)
      end
      def rb2cmis(xml, value)
        xml["c"].value( (!!value).to_s )
      end
    end

    class URI < Singleton
      def to_s
        "Uri"
      end

      def cmis2rb(value)
        URI.parse(value.text)
      end
      def rb2cmis(xml, value)
        xml["c"].value( value.to_s )
      end
    end

    class ID < Singleton
      def to_s
        "Id"
      end

      def cmis2rb(value)
        value.text
      end
      def rb2cmis(xml, value)
        xml["c"].value( value.to_s )
      end
    end

    class HTML < Singleton
      def to_s
        "Html"
      end

      def cmis2rb(value)
        value
      end
      def rb2cmis(xml, value)
        # FIXME: Test that this works
        xml["c"].value value
      end
    end
  end
end
