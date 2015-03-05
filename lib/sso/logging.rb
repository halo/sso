module SSO
  module Logging

    def debug(&block)
      logger.debug progname, &block
    end

    def info(&block)
      logger.info progname, &block
    end

    def warn(&block)
      logger.warn progname, &block
    end

    def error(&block)
      logger.error progname, &block
    end

    def progname
      self.class.name == 'Module' ? self.name : self.class.name
    end

    def logger
      ::SSO.config.logger
    end

  end
end
