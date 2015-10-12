# Builds Rack APP
module AUTH
  class << self
    def app
      Rack::Builder.new do
        run ::AUTH::V1
      end
    end

    def initialize! **options
    end
  end
end
