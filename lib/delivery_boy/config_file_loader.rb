module DeliveryBoy
  class ConfigFileLoader
    def initialize(config)
      @config = config
    end

    def load_file(path, environment)
      # First, load the ERB template from disk.
      template = ERB.new(File.new(path).read)

      # The last argument to `safe_load` allows us to use aliasing to share
      # configuration between environments.
      processed = YAML.safe_load(template.result(binding), [], [], true)

      processed.fetch(environment).each do |variable, value|
        @config.set(variable, value)
      end
    end
  end
end
