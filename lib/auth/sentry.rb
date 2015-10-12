module Oauth2
  class Sentry
    class User
      def initialize(id); @id = id; end
      def id; @id; end
    end

    def initialize(request)
      @request = request
    end
    
    def authenticate!(user_type=:default)
      case user_type.to_sym
      when :client
        @client = Oauth2.authenticate_client(@request.params['client_id'], @request.params['client_secret'])
        unless @client
          raise UnauthorizedClient, 'Invalid client'
        end
      else
        if Oauth2.authenticate_account(@request.params['username'], @request.params['password'])
          @user = User.new(@request.params['username'])
        else
          raise AccessDenied, 'Invalid username or password'
        end
      end
    end

    def user(domain=:default)
      case domain.to_sym
      when :client
        @client ? @client : nil
      else
        @user ? @user : nil
      end
    end
  end
end
