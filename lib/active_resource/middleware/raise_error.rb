module ActiveResource
  module Response
    class RaiseError < ::Faraday::Response::Middleware
      def on_complete(env)
        case env[:status]
          when 301, 302, 303, 307
            raise(ActiveResource::Redirection.new(response_values(env)))
          # when 200...400
            # response
          when 400
            raise(ActiveResource::BadRequest.new(response_values(env)))
          when 401
            raise(ActiveResource::UnauthorizedAccess.new(response_values(env)))
          when 403
            raise(ActiveResource::ForbiddenAccess.new(response_values(env)))
          when 404
            raise(ActiveResource::ResourceNotFound.new(response_values(env)))
          when 405
            raise(ActiveResource::MethodNotAllowed.new(response_values(env)))
          when 409
            raise(ActiveResource::ResourceConflict.new(response_values(env)))
          when 410
            raise(ActiveResource::ResourceGone.new(response_values(env)))
          when 422
            raise(ActiveResource::ResourceInvalid.new(response_values(env)))
          when 401...500
            raise(ActiveResource::ClientError.new(response_values(env)))
          when 500...600
            raise(ActiveResource::ServerError.new(response_values(env)))
          # else
            # raise(ActiveResource::ConnectionError.new(env, "Unknown response code: #{env[:status]}"))
        end
      end

      def response_values(env)
        {:status => env[:status], :headers => env[:response_headers], :body => env[:body]}
      end
    end
  end
end
