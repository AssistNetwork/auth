require 'rubygems'
require 'grape'
require 'json'
require 'csv'
require 'rack/cors'
require 'erb'
require 'cgi'
require 'uri'
require 'slim'

require_relative '../auth_helpers'
require_relative '../auth_errors'

require_relative '../../lib/auth'

LIMIT = 20

module AUTH
  class V1 < ::Grape::API
    prefix 'api'
    format :json
    version %w{ v1 }, using: :header, vendor: 'assist-network', format: :json
    helpers AuthHelpers

    use Rack::Cors do
      allow do
        origins '*'
        resource '*', headers: :any, methods: [:get, :post, :put, :delete]
      end
    end

    use Rack::Session::Cookie, secret: ::AUTH.configuration.session_secret

    #before do # TODO default response header setting
    #  headers['Cache-Control'] = 'no-store'
    #end

    desc 'Returns current API version and environment.'
    get do
      { version: 'v1', environment: ENV['RACK_ENV'] }
    end

    dir = File.dirname(File.expand_path(__FILE__))
    # LOADPATH
    # set :views,  '/www/views'
    # set :public_folder, '/www/public'



    resource :admin do

      desc 'Return list of clients'
      params do
        requires :name, type: String , desc: 'Client name'
        optional :page, type: Integer, desc: 'Page num'
        optional :limit, type: Integer, desc: 'Page size'
      end
      get :list do
        authenticate!
        set = Oauth2.find(client: params['name'])
        paginate(set, params[:id], params[:limit])
      end
    end

    resource :authorize

    desc ' Clients authorization'
    params do
      requires :response_type, type:String , desc: 'Response type'
    end
    get do
      sentry.authenticate!(:client)
      validate_redirect_uri!
      unless ['code', 'token', 'code_and_token', nil].include?(response_type)
        #unless ['code', nil].include?(:response_type)
        raise UnsupportedResponseType,
              'The authorization www does not support obtaining an ' +
                  'authorization code using this method.'
      end
      @client = sentry.user(:client)
      slim(:auth_login)
    end

    post do
      sentry.authenticate!(:client)
      @client = sentry.user(:client)
      raise UnauthorizedClient, 'Invalid client' unless @client.secret
      validate_redirect_uri!
      params[:username], params[:password] = Oauth2.extract_form_post_code(params[:form_post_code])
      sentry.authenticate!
      case params[:response_type]
        when 'code', nil
          authorization_code = Oauth2.issue_code(sentry.user.id,
                                                 sentry.user(:client).id,
                                                 params[:redirect_uri],
                                                 params[:scope])
          redirect_uri = merge_uri_with_query_parameters(
              params[:redirect_uri],
              :code => authorization_code,
              :state => params[:state])
          redirect redirect_uri
        when 'token'
          ttl = ENV['AUTH_TOKEN_TTL'].to_i
          access_token = Oauth2.issue_token(sentry.user.id, params[:scope], ttl)
          redirect_uri = merge_uri_with_fragment_parameters(
              params[:redirect_uri],
              :access_token => access_token,
              :token_type => 'bearer',
              :expires_in => ttl,
              :expires => ttl, # Facebook compatibility
              :scope => params[:scope],
              :state => params[:state])
          redirect redirect_uri
        when 'code_and_token'
          ttl = ENV['AUTH_TOKEN_TTL'].to_i
          authorization_code = Oauth2.issue_code(sentry.user.id,
                                                 sentry.user(:client).id,
                                                 params[:redirect_uri],
                                                 params[:scope])
          access_token = Oauth2.issue_token(sentry.user.id, params[:scope], ttl)
          redirect_uri = merge_uri_with_fragment_parameters(
              params[:redirect_uri],
              :code => authorization_code,
              :access_token => access_token,
              :token_type => 'bearer',
              :expires_in => ttl,
              :expires => ttl, # Facebook compatibility
              :scope => params[:scope],
              :state => params[:state])
          redirect redirect_uri
        else
          raise UnsupportedResponseType,
                'The authorization www does not support obtaining an ' +
                    'authorization code using this method.'
      end
    end

    post :grant do
      sentry.authenticate!(:client)
      validate_redirect_uri!
      sentry.authenticate!
      @client = sentry.user(:client)
      @client.form_post_code = Oauth2.issue_form_post_code(params[:username], params[:password])
      slim(:auth_permissions)
    end

    post :token, :access_token do
      sentry.authenticate!(:client)
      validate_redirect_uri!
      case params[:grant_type]
        when 'authorization_code', nil
          account_id, scopes = Oauth2.validate_code(
              params[:code], sentry.user(:client).id, params[:redirect_uri])
          if account_id
            ttl = ENV['AUTH_TOKEN_TTL'].to_i
            access_token = Oauth2.issue_token(account_id, scopes, ttl)
            @token = {
                :access_token => access_token,
                :token_type => 'bearer',
                :expires_in => ttl,
                :expires => ttl, # Facebook compatibility
                :scope => scopes
            }
          else
            raise AuthException, 'Invalid authorization code'
          end
        when 'password'
          sentry.authenticate!
          ttl = ENV['AUTH_TOKEN_TTL'].to_i
          access_token = Oauth2.issue_token(sentry.user.id, params[:scope], ttl)
          @token = {
              :access_token => access_token,
              :token_type => 'bearer',
              :expires_in => ttl,
              :expires => ttl, # Facebook compatibility
              :scope => params[:scope]
          }
        when 'refresh_token'
          raise AuthException, 'Unsupported grant type'
        when 'client_credentials'
          access_token = Oauth2.issue_token("client:#{sentry.user(:client).id}")
          @token = {
              :access_token => access_token,
              :token_type => 'client'
          }
        else
          raise AuthException, 'Unsupported grant type'
      end
      if request.accept.include?('application/json')
        headers['Content-Type'] = 'application/json;charset=utf-8'
        [200, @token.to_json]
      else
        headers['Content-Type'] = 'application/x-www-form-urlencoded;charset=utf-8'
        [200, query_string(@token)]
      end
    end

    get :validate do
      sentry.authenticate!(:client)
      headers['Content-Type'] = 'text/plain;charset=utf-8'
      if account_id == Oauth2.validate_token(params[:access_token], params[:scope])
        [200, account_id]
      else
        [403, 'Forbidden']
      end
    end

  end
end
