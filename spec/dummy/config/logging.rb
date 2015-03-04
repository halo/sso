Logging::Rails.configure do |config|

  Logging.color_scheme( 'bright',
    levels: {
      debug: :blue,
      info: :green,
      warn: :yellow,
      error: :red,
      fatal: :red,
    },
    date: :blue,
    logger: :blue,
  )

  layout = Logging.layouts.pattern pattern: '%c : %m\n', color_scheme: 'bright'

  Logging.appenders.stdout( 'stdout',
    auto_flushing: true,
    layout: layout,
  ) if config.log_to.include? 'stdout'

  Logging.appenders.rolling_file( 'file',
    filename: config.paths['log'].first,
    auto_flushing: true,
    layout: layout,
  ) if config.log_to.include? 'file'

  Logging.logger.root.level     = config.log_level
  Logging.logger.root.appenders = config.log_to unless config.log_to.empty?

end
