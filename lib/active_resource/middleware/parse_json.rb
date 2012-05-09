module ActiveResource
  module Middleware
    
    class ParseJSON < Faraday::Middleware
      # Parse the response body
      #
      # @param [String] body The response body
      # @return [Mixed] the parsed response
      def decode(json)
        Formats.remove_root(ActiveSupport::JSON.decode(json))
      end
      
      # Parse the request
      #
      # @param [String, Hash] body The request body in Hash or String format, a string will be passed along unchanged
      # @param [options] options Passed along to ActiveSupport::JSON.encode if the first param is a hash
      # @return [String]
      def encode(body, options = nil)
        return body if body.is_a?(String)
        ActiveSupport::JSON.encode(body, options)
      end
      
      # request phase
      def call(env)
        env[:body] = encode(env[:body])
        @app.call(env).on_complete do # response phase
          env[:body] = decode(env[:body]) unless env[:body].blank?
        end
      end
    end
  end
end
