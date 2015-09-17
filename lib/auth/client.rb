module Auth
  class Client
    include Helpers

    def initialize(attributes = {})
      @id = attributes[:id]
      @name = attributes[:name]
      @redirect_uri = attributes[:redirect_uri]
      unless @secret = attributes[:secret]
        @secret = generate_secret
      end
    end


    def id
      @id
    end

    def name
      @name
    end

    def secret
      @secret
    end

    def redirect_uri
      @redirect_uri
    end

  end
end
