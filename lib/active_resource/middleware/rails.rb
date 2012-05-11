module ActiveResource
  module Middleware
    class Rails < Faraday::Middleware

      def call(env)
        @app.call(env).on_complete do
          env[:body] = ActiveResource::Middleware::Formats.remove_root(env[:body])
        end
      end

    end
  end
end
