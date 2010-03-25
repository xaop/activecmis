module ActiveCMIS
  # Default logger: Outputs to STDOUT and has level set to DEBUG
  def self.default_logger
    @default_logger ||= Logger.new(STDOUT)
  end

  # Will search for a given configuration in a file, and return the equivalent Repository
  #
  # server_url and repository_id are required options
  #
  # server_login, server_password and server_auth can be used to authenticate against the server,
  # server_auth is optional and defaults to :basic
  #
  # You can also authenticate to the repository, by replacing server_ with repository_, by default
  # the repository will use the same authentication parameters as the server
  #
  # The amoung of logging can be configured by setting log_level (default WARN), this can be done either
  # by naming a Logger::Severity constant or the equivalent integer
  #
  # The destination of the logger output can be set with log_file (defaults to STDOUT), (should not contain ~)
  #
  # Default locations for the config file are: ./cmis.yml and .cmis.yml in that order
  def self.load_config(config_name, file = nil)
    if file.nil?
      ["cmis.yml", File.join(ENV["HOME"], ".cmis.yml")].each do |sl|
        if File.exist?(sl)
          file ||= sl
        end
      end
      if file.nil?
        raise "No configuration provided, and none found in standard locations"
      end
    elsif !File.exist?(file)
      raise "Configuration file #{file} does not exist"
    end

    config = YAML.load_file(file)
    if config.is_a? Hash
      config = config[config_name]
      if config.is_a? Hash
        if config.has_key? "log_file"
          logger = Logger.new(config["trace_file"])
        else
          logger = default_logger
        end
        if config.has_key? "log_level"
          logger.level = Logger.const_get(config["trace_level"].upcase) rescue config["trace_level"].to_i
        else
          logger.level = Logger::WARN
        end

        server = Server.new(config["server_url"], logger)
        if user_name = config["server_login"] and password = config["server_password"]
          auth_type = config["server_auth"] || :basic
          server.authenticate(auth_type, user_name, password)
        end
        repository = server.repository(config["repository_id"])
        if user_name = config["repository_login"] and password = config["repository_password"]
          auth_type = config["repository_auth"] || :basic
          repository.authenticate(auth_type, user_name, password)
        end
        return repository
      elsif config.nil?
        raise "Configuration not found in file"
      else
        raise "Configuration does not have right format (not a hash)"
      end
    else
      raise "Configuration file does not have right format (not a hash)"
    end
  end
end
