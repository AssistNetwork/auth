require_relative 'test_helper'

class NamespaceTest < Minitest::Test

  def test_can_set_a_namespace
    assert Auth.redis
    assert_equal :auth, Auth.redis.namespace
    Auth.redis = 'redis://localhost:6379/namespace'
    assert_equal 'namespace', Auth.redis.namespace
  end

end