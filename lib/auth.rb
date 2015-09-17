require 'redis'
require 'redis/namespace'
require 'json'
require 'uri'

ENV['AUTH_HASH_ALGORITHM'] ||= 'sha256'
ENV['AUTH_TOKEN_TTL'] ||= '3600'

require_relative 'auth/version'
require_relative 'auth/exceptions'
require_relative 'auth/helpers'
require_relative 'auth/client'
require_relative 'auth/sentry'

module Auth
  include Helpers
  extend self

  # Accepts:
  #   1. A 'hostname:port' string
  #   2. A 'hostname:port:db' string (to select the Redis db)
  #   3. A 'hostname:port/namespace' string (to set the Redis namespace)
  #   4. A redis URL string 'redis://host:port'
  #   5. An instance of `Redis`, `Redis::Client`, `Redis::DistRedis`,
  #      or `Redis::Namespace`.
  def redis=(server)
    if server.respond_to? :split
      if server =~ /redis\:\/\// # URI parse
        begin
          uri = URI(server)
        rescue URI::InvalidURIError
          return NIL
        end
        namespace = uri.path.to_s.gsub(Regexp.new('^/'),'')
        redis = Redis.new(:url => server)
      else
        server, namespace = server.split('/', 2)
        host, port, db = server.split(':')
        redis = Redis.new(:host => host, :port => port,
                          :thread_safe => true, :db => db)
      end
      namespace ||= :auth
      @redis = Redis::Namespace.new(namespace, :redis => redis)
    elsif server.respond_to? :namespace=
      @redis = server
    else
      @redis = Redis::Namespace.new(:auth, :redis => server)
    end
  end

  # Returns the current Redis connection. If none has been created, will
  # create a new one.
  def redis
    return @redis if @redis
    namespace ||= :auth
    @redis = Redis::Namespace.new(namespace)
  end

  #
  # Sentry
  #

  def sentry=(sentry)
    @sentry = sentry
  end

  def sentry
    @sentry
  end

  #
  # Accounts
  #

  def register_account(username, password)
    raise if username.nil? || username == ''
    raise if password.nil? || password == ''
    if redis.exists("account:#{username}")
      false # Account exist
    else
      hash = ENV['AUTH_HASH_ALGORITHM']
      salt = generate_secret
      crypted_password = encrypt_password(password, salt, hash)
      redis.hmset("account:#{username}", 'crypted_password', crypted_password,
                                         'password_hash', hash,
                                         'password_salt', salt)
      true
    end
  end

  def authenticate_account(username, password)
    account = redis.hgetall("account:#{username}")
    if account['crypted_password']
      crypted_password = encrypt_password(password,
                                          account['password_salt'],
                                          account['password_hash'])
      if crypted_password == account['crypted_password']
        true
      else
        false
      end
    else
      false
    end
  end

  def change_password(username, old_password, new_password)
    if authenticate_account(username, old_password)
      hash = ENV['AUTH_HASH_ALGORITHM']
      salt = generate_secret
      crypted_password = encrypt_password(new_password, salt, hash)
      redis.hmset("account:#{username}", 'crypted_password', crypted_password,
                                         'password_hash', hash,
                                         'password_salt', salt)
    end
  end

  def remove_account(username)
    redis.del("account:#{username}")
  end

  #
  # Clients
  #

  def register_client(client_id, name, redirect_uri)
    raise if client_id.nil? || client_id == ''
    raise if name.nil? || name == ''
    raise if redirect_uri.nil? || redirect_uri == ''
    client = { :id => client_id,
               :name => name,
               :redirect_uri => redirect_uri }
    if redis.exists("client:#{client_id}")
      false # Double registration
    else
      client[:secret] = generate_secret
      client.each do |key,val|
        redis.hset("client:#{client_id}", key, val)
      end
      Client.new(client)
    end
  end

  def authenticate_client(client_id, client_secret = nil)
    client = Hash[redis.hgetall("client:#{client_id}").map{|(k,v)| [k.to_sym,v]}]
    #client = Hash[client.map{|(k,v)| [k.to_sym,v]}]
    if client_secret
      client[:id] && client[:secret] == client_secret ? Client.new(client) : false
    else
      client[:id].nil? ?  false : Client.new(client)
    end
  end

  def remove_client(client_id)
    redis.del("client:#{client_id}")
  end

  #
  # Authorization codes
  #

  def issue_code(account_id, client_id, redirect_uri, scopes = nil)
    code = generate_secret
    redis.set("code:#{client_id}:#{redirect_uri}:#{code}:account", account_id)
    decode_scopes(scopes).each do |scope|
      redis.sadd("code:#{client_id}:#{redirect_uri}:#{code}:scopes", scope)
    end
    redis.expire("code:#{client_id}:#{redirect_uri}:#{code}:account", 3600)
    redis.expire("code:#{client_id}:#{redirect_uri}:#{code}:scopes", 3600)
    code
  end

  def validate_code(code, client_id, redirect_uri)
    account_id = redis.get("code:#{client_id}:#{redirect_uri}:#{code}:account")
    scopes = redis.smembers("code:#{client_id}:#{redirect_uri}:#{code}:scopes")
    account_id ? [account_id, encode_scopes(scopes)]: false
  end

  #
  # Access tokens
  #

  def issue_token(account_id, scopes = nil, ttl = nil)
    token = generate_secret
    redis.set("token:#{token}:account", account_id)
    decode_scopes(scopes).each do |scope|
      redis.sadd("token:#{token}:scopes", scope)
    end
    if ttl
      redis.expire("token:#{token}:account", ttl)
      redis.expire("token:#{token}:scopes", ttl)
    end
    token
  end

  def validate_token(token, scopes = nil)
    account_id = redis.get("token:#{token}:account")
    if account_id && 
       decode_scopes(scopes).all? {|scope|
         redis.sismember("token:#{token}:scopes", scope) }
      account_id
    else
      false
    end
  end

end