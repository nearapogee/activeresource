require 'active_support/core_ext/hash/conversions'

module ActiveResource
  module Middleware
    module Formats
      class XmlFormat < Faraday::Middleware
        CONTENT_TYPE = 'Content-Type'.freeze
        MIME_TYPE = 'text/xml'
        
        class << self
          def extension
            'xml'
          end
          def mime_type
            MIME_TYPE
          end
          # Parse the response body
          #
          # @param [String] body The response body
          # @return [Mixed] the parsed response
          def decode(xml)
            Hash.from_xml(xml)
          end

          # Parse the request
          #
          # @param [Hash] body The request body in Hash or String format, a string will be passed along unchanged
          # @param [options] options Passed along to ActiveSupport::JSON.encode if the first param is a hash
          # @return [String]
          def encode(body, options={})

            # TODO: This to_xml does not match json's method. Wraps entire data structure
            # in a <hash/> element.
            body.to_xml(options) if body.respond_to?(:to_xml)
          end
        end
      
        def call(env)
          # request phase
          env[:request_headers][CONTENT_TYPE] ||= MIME_TYPE
          env[:body] = self.class.encode(env[:body]) unless env[:body].blank?

          # response phase
          @app.call(env).on_complete do
            env[:body] = self.class.decode(env[:body]) unless env[:body].blank?
          end
        end
      
      end
    end
  end
end

