require 'active_support/json'
module ActiveResource
  module Middleware
    module Formats
      class JsonFormat < Faraday::Middleware
        CONTENT_TYPE = 'Content-Type'.freeze
        MIME_TYPE = 'application/json'

        class << self
          # this should go away
          def extension
            'json'
          end
          def mime_type
            MIME_TYPE
          end
          # Parse the response body
          #
          # @param [String] body The response body
          # @return [Mixed] the parsed response
          def decode(json)
            ActiveSupport::JSON.decode(json)
          end

          # Parse the request
          #
          # @param [String, Hash] body The request body in Hash or String format, a string will be passed along unchanged
          # @param [options] options Passed along to ActiveSupport::JSON.encode if the first param is a hash
          # @return [String]
          def encode(body, options = {})
            return body if body.is_a?(String)
            ActiveSupport::JSON.encode(body, options)
          end
        end
      
        # request phase
        def call(env)
          env[:request_headers][CONTENT_TYPE] ||= MIME_TYPE
          env[:body] = self.class.encode(env[:body])
          @app.call(env).on_complete do # response phase
            env[:body] = self.class.decode(env[:body]) unless env[:body].blank?
          end
        end
      end
    end
  end
end

