module SSO
  module Logging

    def debug(&block)
      logger.debug self.class.name, &block
    end

    def info(&block)
      logger.info self.class.name, &block
    end

    def warn(&block)
      logger.warn self.class.name, &block
    end

    def logger
      ::SSO.config.logger
    end

  end
end
