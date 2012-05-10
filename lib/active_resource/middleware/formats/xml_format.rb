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
            Formats.remove_root(Hash.from_xml(xml))
          end

          # Parse the request
          #
          # @param [Hash] body The request body in Hash or String format, a string will be passed along unchanged
          # @param [options] options Passed along to ActiveSupport::JSON.encode if the first param is a hash
          # @return [String]
          def encode(hash, options = nil)
            hash.to_xml(options)
          end
        end
      
        def call(env)
          env[:request_headers][CONTENT_TYPE] ||= MIME_TYPE
          # request phase
          env[:body] = self.class.encode(env[:body]) unless env[:body].blank?
        
          @app.call(env).on_complete do # response phase
            env[:body] = self.class.decode(env[:body]) unless env[:body].blank?
          end
        end
      
      end
    end
  end
end

