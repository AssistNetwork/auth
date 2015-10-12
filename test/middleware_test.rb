require_relative 'test_helper'
require '../lib/auth/middleware'

class MiddlewareTest < Minitest::Test
  include Rack::Test::Methods

  def inner_app
    lambda { |env| [200, {'Content-Type' => 'text/plain'}, [env['REMOTE_USER']]] }
  end

  def app
    Oauth2::Middleware.new(inner_app, 'Test realm')
  end

  def unprotected_app
    Oauth2::Middleware.new(inner_app, 'Test realm', :allow_unauthenticated => true)
  end

  def setup
    Oauth2.redis.flushall
    Oauth2.register_account('test', 'test')
    @client = Oauth2.register_client('test-client', 'test', 'https://example.com/')
    @authorization_code = Oauth2.issue_code('test-account', @client.id, @client.redirect_uri, 'read write')
  end

  def test_unauthenticated_request
    env = Rack::MockRequest.env_for('/test')
    res = app.call(env)
    assert_equal 401, res[0]
    assert_equal 'Bearer realm="Test realm"', res[1]['WWW-Authenticate']
    assert_empty res[2]
  end

  def test_authenticated_request
    token = Oauth2.issue_token('test-user')
    env = Rack::MockRequest.env_for('/test',
      'HTTP_AUTHORIZATION' => "Bearer #{Base64.encode64(token)}")
    res = app.call(env)
    assert_equal 200, res[0]
    assert_equal nil, res[1]['WWW-Authenticate']
    assert_equal ['test-user'], res[2]
  end

  def test_authenticated_non_bearer_request
    env = Rack::MockRequest.env_for('/test',
      'HTTP_AUTHORIZATION' => "Basic #{Base64.encode64('test')}")
    res = app.call(env)
    assert_equal 400, res[0]
    assert_equal nil, res[1]['WWW-Authenticate']
    assert_empty res[2]
  end

  def test_authenticated_invalid_request
    env = Rack::MockRequest.env_for('/test',
      'HTTP_AUTHORIZATION' => "Bearer #{Base64.encode64('wrong')}")
    res = app.call(env)
    assert_equal 401, res[0]
    assert_equal 'Bearer realm="Test realm"', res[1]['WWW-Authenticate']
    assert_empty res[2]
  end

  def test_unauthenticated_request_on_unprotected_app
    env = Rack::MockRequest.env_for('/test')
    res = unprotected_app.call(env)
    assert_equal 200, res[0]
    assert_equal 'Bearer realm="Test realm"', res[1]['WWW-Authenticate']
    assert_equal [nil], res[2]
  end

  def test_authenticated_request_on_unprotected_app
    token = Oauth2.issue_token('test-user')
    env = Rack::MockRequest.env_for('/test',
      'HTTP_AUTHORIZATION' => "Bearer #{Base64.encode64(token)}")
    res = unprotected_app.call(env)
    assert_equal 200, res[0]
    assert_equal nil, res[1]['WWW-Authenticate']
    assert_equal ['test-user'], res[2]
  end

  def test_authenticated_request_with_query_parameter
    token = Oauth2.issue_token('test-user')
    env = Rack::MockRequest.env_for("/test?access_token=#{CGI.escape(token)}")
    res = app.call(env)
    assert_equal 200, res[0]
    assert_equal nil, res[1]['WWW-Authenticate']
    assert_equal ['test-user'], res[2]
  end

end