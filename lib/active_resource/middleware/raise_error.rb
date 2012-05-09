module ActiveResource
  module Response
    class RaiseError < ::Faraday::Response::Middleware

      def on_complete(env)
        case env[:status]
          when 301, 302, 303, 307
            raise(ActiveResource::Redirection.new(env))
          when 200...400
            # nothing to raise here
          when 400
            raise(ActiveResource::BadRequest.new(env))
          when 401
            raise(ActiveResource::UnauthorizedAccess.new(env))
          when 403
            raise(ActiveResource::ForbiddenAccess.new(env))
          when 404
            raise(ActiveResource::ResourceNotFound.new(env))
          when 405
            raise(ActiveResource::MethodNotAllowed.new(env))
          when 409
            raise(ActiveResource::ResourceConflict.new(env))
          when 410
            raise(ActiveResource::ResourceGone.new(env))
          when 422
            raise(ActiveResource::ResourceInvalid.new(env))
          when 401...500
            raise(ActiveResource::ClientError.new(env))
          when 500...600
            raise(ActiveResource::ServerError.new(env))
          else
            raise(ActiveResource::ConnectionError.new(env, "Unknown response code: #{env[:status]}"))
        end
      end

    end
  end
end
