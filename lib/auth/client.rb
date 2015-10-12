module Oauth2
  class Client
    def initialize(attributes)
      @attributes = attributes
    end

    def method_missing(method)
      @attributes[method.to_s] || @attributes[method.to_sym]
    end

    def form_post_code=(code)
      @attributes['form_post_code'] = code
    end
  end
end
