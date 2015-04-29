module SSO
  module Meter
    include ::SSO::Logging

    def track(key:, value: 1, tags: nil, data: {})
      data[:caller] = caller_name
      debug { "Measuring increment #{key.inspect} with value #{value.inspect} and tags #{tags.inspect} and data #{data.inspect}" }
      metric.call type: :increment, key: "sso.#{key}", value: value, tags: tags, data: data

    rescue => exception
      ::SSO.config.exception_handler.call exception
    end

    def timing(key:, value:, tags: nil, data: {})
      data[:caller] = caller_name
      debug { "Measuring timing #{key.inspect} with value #{value.inspect} and tags #{tags.inspect} and data #{data.inspect}" }
      metric.call type: :timing, key: "sso.#{key}", value: value, tags: tags, data: data

    rescue => exception
      ::SSO.config.exception_handler.call exception
    end

    def caller_name
      self.class.name
    end

    def metric
      ::SSO.config.metric
    end

  end
end
