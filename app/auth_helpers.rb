#require 'redis'

module AuthHelpers


  include Rack::Utils
  alias_method :h, :escape_html

  def cgi_escape(text)
      URI.escape(CGI.escape(text.to_s), '.').gsub(' ','+')
    end

  def query_string(parameters, escape = true)
      if escape
        parameters.map{|key,val| val ? "#{cgi_escape(key)}=#{cgi_escape(val)}" : nil }.compact.join('&')
      else
        parameters.map{|key,val| val ? "#{key}=#{val}" : nil }.compact.join('&')
      end
    end

  def merge_uri_with_query_parameters(uri, parameters = {})
      parameters = query_string(parameters)
      if uri.to_s =~ /\?/
        parameters = "&#{parameters}"
      else
        parameters = "?#{parameters}"
      end
      URI.escape(uri.to_s) + parameters.to_s
    end

  def merge_uri_with_fragment_parameters(uri, parameters = {})
      parameters = query_string(parameters)
      parameters = "##{parameters}"
      URI.escape(uri.to_s) + parameters.to_s
    end

  def merge_uri_based_on_response_type(uri, parameters = {})
      case params[:response_type]
        when 'code', nil
          merge_uri_with_query_parameters(uri, parameters)
        when 'token', 'code_and_token'
          merge_uri_with_fragment_parameters(uri, parameters)
        else
          halt(400, 'Unsupported response type request')
      end
    end

  def sentry
      if Oauth2.sentry
        @sentry ||= Oauth2.sentry.new(request)
      else
        @sentry ||= request.env['warden'] || request.env['rack.auth'] || Sentry.new(request)
      end
    end

  def validate_redirect_uri!
      params[:redirect_uri] ||= sentry.user(:client).redirect_uri
      if URI(params[:redirect_uri]).host.to_s.downcase != URI(sentry.user(:client).redirect_uri).host.to_s.downcase
        halt(400, 'Invalid redirect URI')
      end
    rescue URI::InvalidURIError
      halt(400, 'Invalid redirect URI')
    end


  def authenticate!
    error!('401 Unauthorized', 401) unless headers['Auth'] == 'tokenke' #TODO rendesen bekötni a UI app-ot regisztrálva
  end

  def paginate(set, page_num, limit)

    if limit.nil?
      limit = LIMIT
    end

    if page_num.nil?
      page_num = 1
    end

    # Get number of pages
    num_pages = 1 + set.size / limit
    start = (page_num - 1) * limit

    # Select range
    if set.respond_to? :range
      # It's a zset
      limited_set = set.revrange(start, start + limit)
    else
      # Normal set
      limited_set = set.sort(limit: [start, limit], order: 'DESC')
    end

    # Generate response
    page = Array.new
    limited_set.each do |element|
      page << element.to_hash
    end
    {:num_pages => num_pages, :page => page}
  end

  def rescue_db_errors #TODO error handling
    begin
      yield
    rescue Redis::BaseError => e
      AUTH.Logger.new(STDERR).error('Redis Error Rescued. Error message: #{e}.')
      {:success => false}
    end
  end
end
