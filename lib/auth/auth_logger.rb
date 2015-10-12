require 'logger'

# We renamed this file from 'logger.rb' to 'auth_logger.rb' due to clashing
module AUTH
  class << self
    def logger
      @logger ||= heroku? ? ::Logger.new(STDOUT) : ::Logger.new(File.expand_path("../../log/#{ENV["RACK_ENV"]}.log", __dir__))
    end
  end
end
