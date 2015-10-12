require_relative 'test_helper'
require '../lib/auth'

class ApiTest < Minitest::Test
  include Rack::Test::Methods

  def app
    # ide kell definiálni, hogy indítsa újra az API-t
    # TODO
  end

  def setup
    Oauth2.redis.flushall
    Oauth2.register_account('test', 'test')
    @client = Oauth2.register_client('test-client', 'Test', 'https://example.com/callback')
    @authorization_code = Oauth2.issue_code('test-account', @client.id, @client.redirect_uri, 'read write')
    p 'basz'
  end

  def test_should_not_allow_invalid_redirect_uri
    get '/authorize', :client_id => @client.id, :redirect_uri => 'invalid uri'
    assert_equal 400, last_response.status
    get '/authorize', :client_id => @client.id, :redirect_uri => 'https://wrong.com/callback'
    assert_equal 400, last_response.status
    get '/authorize', :client_id => @client.id, :redirect_uri => 'https://wrong.example.com/callback'
    assert_equal 400, last_response.status
  end

  def test_obtaining_end_user_authorization
    get '/authorize',
      :response_type => 'code',
      :client_id => @client.id,
      :redirect_uri => @client.redirect_uri,
      :scope => 'read write',
      :state => 'opaque',
      :username => 'test',
      :password => 'test'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response.headers['Content-Type']
    assert_equal 'no-store', last_response.headers['Cache-Control']
#    assert_match 'code', last_response.body #TODO ez mi?
    assert_match @client.id.to_s, last_response.body
    assert_match 'https://example.com/callback', last_response.body
    assert_match 'read+write', last_response.body
    assert_match 'opaque', last_response.body
  end

=begin
  def test_request_for_authorization_code
    post '/authorize',
      :response_type => 'code',
      :client_id => @client.id,
      :redirect_uri => @client.redirect_uri,
      :scope => 'read write',
      :state => 'opaque',
      :username => 'test',
      :password => 'test'
    assert_equal 302, last_response.status
    assert_equal 'no-store', last_response.headers['Cache-Control']
    location_uri = URI(last_response.headers['Location'])
    assert_equal 'https', location_uri.scheme
    assert_equal 'example.com', location_uri.host
    assert_equal '/callback', location_uri.path
    assert_match /code=[^&]+/, location_uri.query
    assert_match /state=opaque/, location_uri.query
  end

  def test_request_for_access_token_using_authorization_code
    post '/access_token', {
      :grant_type => 'authorization_code',
      :client_id => @client.id,
      :client_secret => @client.secret,
      :redirect_uri => @client.redirect_uri,
      :code => @authorization_code
    }, 'HTTP_ACCEPT' => 'application/json'
    assert_equal 200, last_response.status
    assert_equal 'application/json;charset=utf-8', last_response.headers['Content-Type']
    assert_equal 'no-store', last_response.headers['Cache-Control']
    token = JSON.parse(last_response.body)
    assert token['access_token']
    assert_equal 'bearer', token['token_type']
    assert_equal 3600, token['expires_in']
    assert_equal 'read write', token['scope']
  end

  def test_request_for_access_token_using_password
    post '/access_token', {
      :grant_type => 'password',
      :client_id => @client.id,
      :client_secret => @client.secret,
      :redirect_uri => @client.redirect_uri,
      :scope => 'read write',
      :username => 'test',
      :password => 'test'
    }, 'HTTP_ACCEPT' => 'application/json'
    assert_equal 200, last_response.status
    assert_equal 'application/json;charset=utf-8', last_response.headers['Content-Type']
    assert_equal 'no-store', last_response.headers['Cache-Control']
    token = JSON.parse(last_response.body)
    assert token['access_token']
    assert_equal 'bearer', token['token_type']
    assert_equal 3600, token['expires_in']
    assert_equal 'read write', token['scope']
  end

  def test_request_for_access_token_using_refresh_token
    post '/access_token', {
      :grant_type => 'refresh_token',
      :client_id => @client.id,
      :client_secret => @client.secret,
      :redirect_uri => @client.redirect_uri,
      :refresh_token => '?'
    }, 'HTTP_ACCEPT' => 'application/json'
  #  assert_equal 200, last_response.status # TODO Refresh token
    assert_equal 400, last_response.status
    assert_equal 'application/json;charset=utf-8', last_response.headers['Content-Type']
    assert_equal 'no-store', last_response.headers['Cache-Control']
    token = JSON.parse(last_response.body)
  #  assert token['access_token'] # TODO Refresh token
    assert_equal 'bearer', token['token_type']
    assert_equal 3600*24, token['expires_in']
    assert_equal 'read write', token['scope']
  end

  def test_request_for_access_token_using_client_credentials
    post '/access_token', {
      :grant_type => 'client_credentials',
      :client_id => @client.id,
      :client_secret => @client.secret,
      :redirect_uri => @client.redirect_uri
    }, 'HTTP_ACCEPT' => 'application/json'
    assert_equal 200, last_response.status
    assert_equal 'application/json;charset=utf-8', last_response.headers['Content-Type']
    assert_equal 'no-store', last_response.headers['Cache-Control']
    token = JSON.parse(last_response.body)
    assert token['access_token']
    assert_equal 'client', token['token_type']
  end

  def test_request_for_both_code_and_token
#    Warden.on_next_request do |warden|
      post '/authorize',
        :response_type => 'code_and_token',
        :client_id => 'test-client',
        :redirect_uri => 'https://example.com/callback',
        :scope => 'read write',
        :state => 'opaque'
      assert_equal 302, last_response.status
      location_uri = URI(last_response.headers['Location'])
      assert_equal 'https', location_uri.scheme
      assert_equal 'example.com', location_uri.host
      assert_equal '/callback', location_uri.path
      assert_match /code=/, location_uri.query
      location_uri_fragment_parts = location_uri.fragment.split('&')
      assert_equal true, location_uri_fragment_parts.include?('code=')
      assert_equal true, location_uri_fragment_parts.include?('access_token=')
      assert_equal true, location_uri_fragment_parts.include?('token_type=')
      assert_equal true, location_uri_fragment_parts.include?('expires_in=')
      assert_equal true, location_uri_fragment_parts.include?('scope=')
      assert_equal true, location_uri_fragment_parts.include?('state=')
#    end
  end

  def test_validate_access_token
     basic_authorize @client.username, @client.password
     get '/validate', :token => 'xxx', :client_id => 'test', :scope => 'read write'
     assert_equal 200, last_response.status
  end

  def test_validate_expired_access_token
     basic_authorize @client.username, @client.password
     get '/validate', :token => 'xxx', :client_id => 'test', :scope => 'read write'
     assert_equal 403, last_response.status
  end

  def test_validate_invalid_access_token
     basic_authorize @client.username, @client.password
     get '/validate', :token => 'invalid', :client_id => 'test', :scope => 'read write'
     assert_equal 403, last_response.status
  end

=end
end