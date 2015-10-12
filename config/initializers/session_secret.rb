AUTH.configure do |auth|
  auth.session_secret = ENV['APP_SESSION_SECRET']
  auth.session_secret ||= 'UuEo0OiCvSXRUHmCRahKRQLoDgoBz5lpKmwHxXh3QT89nBcVHljiqzzz0ODs2DiZ' if AUTH.development? or AUTH.test?
  AUTH.logger.error "There is no :session_secret provided!  Please specify one in ENV['APP_SESSION_SECRET']." unless auth.session_secret
end
