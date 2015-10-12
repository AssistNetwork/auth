$LOAD_PATH.unshift 'lib'

require_relative 'config/version'

Gem::Specification.new do |gem|
  gem.name        = 'an-auth'
  gem.version     = AUTH::VERSION
  gem.summary     = 'Oauth2 is a Redis-backed high performance OAuth2 authorization www.'
  gem.description = 'A high performance OAuth2 authorization www using Grape and Redis, extended by Niklas Holmgren Auth.'

  gem.author      = 'Gabor Nagymajtenyi'
  gem.email       = 'gabor.nagymajtenyi@gmail.com'
  gem.homepage    = 'http://github.com/assist-network/auth/'

  gem.require_path  = 'lib'
  gem.files             = %w( README.md Rakefile LICENSE CHANGELOG )
  gem.files            += Dir.glob('lib/**/*')
  gem.files            += Dir.glob('test/**/*')
  gem.files            += Dir.glob('tasks/**/*')

  gem.extra_rdoc_files  = %w(LICENSE README.md)
  gem.rdoc_options      = ['--charset=UTF-8']

  gem.add_dependency 'json'
  gem.add_dependency 'rack-contrib'
#  s.add_dependency 'sinatra'
  gem.add_dependency 'redis-namespace'
  gem.add_dependency 'slim'
  gem.add_dependency 'grape'
  gem.add_dependency 'rack-cors'
  gem.add_dependency 'puma'

# Specification and documentation
#gem.add_development_dependency 'yard'
  gem.add_development_dependency 'rack-test'
  gem.add_development_dependency 'minitest'
  gem.add_development_dependency 'rake'

# Ruby
  gem.required_ruby_version = '>= 2.1.0'
  gem.required_rubygems_version = '>= 2.1.0'

# Files
  unless ENV['DYNO'] # check whether we're running on Heroku or not
    gem.files = `git ls-files`.split
    gem.test_files = Dir['test/**/*']
    gem.executables = Dir['bin/*'].map { |f| File.basename(f) }
  end
end
