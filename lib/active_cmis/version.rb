require 'yaml'
module ActiveCMIS
  module Version
    yaml = YAML.load_file(File.join(File.dirname(__FILE__), '/../../VERSION.yml'))
    MAJOR = yaml[:major]
    MINOR = yaml[:minor]
    PATCH = yaml[:patch]
    STRING = "#{MAJOR}.#{MINOR}.#{PATCH}"
  end
end
