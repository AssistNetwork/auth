require_relative 'test_helper'

class AuthTest < Minitest::Test

  def setup
    Oauth2.redis.flushall
  end

  def test_can_set_a_namespace_through_a_url_like_string
    assert Oauth2.redis
    assert_equal :auth, Oauth2.redis.namespace
    Oauth2.redis = 'localhost:9736/namespace'
    assert_equal 'namespace', Oauth2.redis.namespace
  end

  def test_can_set_a_custom_sentry
    assert_nil Oauth2.sentry
    Oauth2.sentry = Oauth2::Sentry
    assert_equal Oauth2::Sentry, Oauth2.sentry
  end

  def test_can_register_an_account
    assert Oauth2.register_account('test', 'test')
  end

  def test_can_only_register_an_account_once
    assert_equal true, Oauth2.register_account('test', 'test')
    assert_equal false, Oauth2.register_account('test', 'test')
  end

  def test_can_authenticate_account
    Oauth2.register_account('test', 'test')
    assert_equal true, Oauth2.authenticate_account('test', 'test')
    assert_equal false, Oauth2.authenticate_account('test', 'wrong')
    assert_equal false, Oauth2.authenticate_account('wrong', 'wrong')
    assert_equal false, Oauth2.authenticate_account('wrong', 'test')
  end

  def test_can_change_password_for_an_account
    Oauth2.register_account('test', 'test')
    Oauth2.change_password('test', 'test', '123456')
    assert_equal false, Oauth2.authenticate_account('test', 'test')
    assert_equal true, Oauth2.authenticate_account('test', '123456')
  end

  def test_can_remove_account
    Oauth2.register_account('test', 'test')
    Oauth2.remove_account('test')
    assert_equal false, Oauth2.authenticate_account('test', 'test')
  end

  def test_can_register_a_client
    client = Oauth2.register_client('test-client', 'Test client', 'http://example.org/')
    assert_equal 'test-client', client.id
    assert_equal 'Test client', client.name
    assert_equal 'http://example.org/', client.redirect_uri
    assert client.secret
  end

  def test_can_authenticate_a_client
    client = Oauth2.register_client('test-client', 'Test client', 'http://example.org/')
    client = Oauth2.authenticate_client('test-client', client.secret)
    assert_equal 'test-client', client.id
    assert_equal 'Test client', client.name
    assert_equal 'http://example.org/', client.redirect_uri
    assert client.secret
    assert_equal false, Oauth2.authenticate_client('test-client', 'wrong')
    assert_equal false, Oauth2.authenticate_client('wrong', 'wrong')
    assert_equal false, Oauth2.authenticate_client('wrong', client.secret)
    assert_equal false, Oauth2.authenticate_client('wrong')
  end

  def test_can_authenticate_a_client_without_a_client_secret
    Oauth2.register_client('test-client', 'Test client', 'http://example.org/')
    client = Oauth2.authenticate_client('test-client')
    assert_equal 'test-client', client.id
    assert_equal 'Test client', client.name
    assert_equal 'http://example.org/', client.redirect_uri
    assert_equal nil, client.secret
  end

  def test_can_remove_client
    Oauth2.register_client('test-client', 'Test client', 'http://example.org/')
    Oauth2.remove_client('test-client')
    assert_equal false, Oauth2.authenticate_client('test-client')
  end

  def test_can_issue_a_token_for_an_account
    assert Oauth2.issue_token('test-account')
  end

  def test_can_validate_a_token_and_return_the_associated_account_id
    token = Oauth2.issue_token('test-account')
    assert_equal 'test-account', Oauth2.validate_token(token)
    assert_equal false, Oauth2.validate_token('gibberish')
  end

  def test_can_issue_a_token_for_a_specified_set_of_scopes
    assert Oauth2.issue_token('test-account', 'read write offline')
  end

  def test_can_validate_a_token_with_a_specified_set_of_scopes
    token = Oauth2.issue_token('test-account', 'read write offline')
    assert_equal 'test-account', Oauth2.validate_token(token)
    assert_equal 'test-account', Oauth2.validate_token(token, 'read')
    assert_equal 'test-account', Oauth2.validate_token(token, 'write offline')
    assert_equal 'test-account', Oauth2.validate_token(token, 'offline read write')
    assert_equal false, Oauth2.validate_token('gibberish', 'read')
    assert_equal false, Oauth2.validate_token(token, 'delete')
    assert_equal false, Oauth2.validate_token(token, 'read delete')
  end

  def test_can_issue_a_time_limited_token
    assert Oauth2.issue_token('test-account', nil, 3600)
  end

  def test_can_issue_a_refresh_token
    #TODO refresh
    #flunk
  end

  def test_can_redeem_a_refresh_token
    #TODO refresh
    #flunk
  end

  def test_can_issue_an_authorization_code
    assert Oauth2.issue_code('test-account', 'test-client', 'https://example.com/callback')
  end

  def test_can_validate_an_authentication_code
    code = Oauth2.issue_code('test-account', 'test-client', 'https://example.com/callback')
    assert_equal ['test-account', ''], Oauth2.validate_code(code, 'test-client', 'https://example.com/callback')
    assert_equal false, Oauth2.validate_code(code, 'wrong-client', 'https://example.com/callback')
    assert_equal false, Oauth2.validate_code(code, 'test-client', 'https://example.com/wrong-callback')
  end

  def test_can_issue_an_authorization_code_for_a_specified_set_of_scopes
    assert Oauth2.issue_code('test-account', 'test-client', 'https://example.com/callback', 'read write offline')
  end

  def test_can_validate_an_authentication_code_with_a_specified_set_of_scopes
    code = Oauth2.issue_code('test-account', 'test-client', 'https://example.com/callback', 'read write offline')
    account_id, scopes = Oauth2.validate_code(code, 'test-client', 'https://example.com/callback')
    assert_equal 'test-account', account_id
    assert_equal 'offline read write', scopes
  end
end