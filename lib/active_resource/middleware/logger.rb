module ActiveResource
  module Middleware
    class Logger < Faraday::Middleware

      def call(env)
        @start = Time.now
        @app.call(env).on_complete do
          ActiveSupport::Notifications.instrument("request.active_resource") do |payload|
            payload[:method]      = env[:method]
            payload[:request_uri] = env[:url]
            payload[:result]      = env[:response]
            payload[:duration]    = (Time.now - @start) * 1000.0
          end
        end
      end

    end
  end
end
