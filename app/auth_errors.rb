# trap all exceptions and fail gracefuly with a 500 and a proper message
class ApiErrorHandler < Grape::Middleware::Base


  def call!(env)
    @env = env
    begin
      @app.call(@env)

=begin
    rescue AuthException => e
      headers['Content-Type'] = 'application/json;charset=utf-8'
        [400, {
                :error => {
                    :type => 'OAuthException',
                    :message => request.env['grape.error'].message
                }
            }.to_json]
    end

    rescue UnsupportedResponseType => e
        redirect_uri = merge_uri_based_on_response_type(
            params[:redirect_uri],
            :error => 'unsupported_response_type',
            :error_description => request.env['grape.error'].message,
            :state => params[:state])
        redirect redirect_uri
    end
=end

    rescue Exception => e
      throw :error, :message => e.message || options[:default_message], :status => 500
    end

  end
end