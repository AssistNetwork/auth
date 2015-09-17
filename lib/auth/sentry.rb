module Auth
  class Sentry
    class User
      def initialize(id, redirect_uri=NIL)
        @id = id
        @redirect_uri = redirect_uri unless redirect_uri
      end
      def id
        @id
      end
      def redirect_uri
        @redirect_uri
      end
    end

    def initialize(request)
      @request = request
    end

    def authenticate!(domain=:default)
      case domain.to_sym
      when :client
        @client = Auth.authenticate_client(@request.params['client_id'], @request.params['client_secret'])
        unless @client
          raise UnauthorizedClient, 'Invalid client'
        end
      else
        if Auth.authenticate_account(@request.params['username'], @request.params['password'])
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
