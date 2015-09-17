$LOAD_PATH.unshift 'lib'
require 'auth/version'

Gem::Specification.new do |s|
  s.name        = 'auth'
  s.version     = Auth::Version
  s.summary     = 'Auth is a Redis-backed high performance OAuth2 authorization server.'
  s.description = 'A high performance OAuth2 authorization server using Sinatra and Redis, inspired by Resque.'

  s.author      = 'Niklas Holmgren'
  s.email       = 'niklas@sutajio.se'
  s.homepage    = 'http://github.com/sutajio/auth/'

  s.require_path  = 'lib'

  s.files             = %w( README.md Rakefile LICENSE CHANGELOG )
  s.files            += Dir.glob("lib/**/*")
  s.files            += Dir.glob("test/**/*")
  s.files            += Dir.glob("tasks/**/*")

  s.extra_rdoc_files  = [ "LICENSE", "README.md" ]
  s.rdoc_options      = ["--charset=UTF-8"]

  s.add_dependency('json')
  s.add_dependency('rack-contrib')
  s.add_dependency('sinatra')
  s.add_dependency('redis-namespace')

  s.add_development_dependency('rack-test')
  s.add_development_dependency('minitest')
end