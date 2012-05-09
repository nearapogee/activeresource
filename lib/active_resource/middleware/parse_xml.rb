module ActiveResource
  module Middleware
    
    class ParseXML < Faraday::Middleware
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
      
      def call(env)
        # request phase
        env[:body] = encode(env[:body]) unless env[:body].blank?
        
        @app.call(env).on_complete do # response phase
          env[:body] = decode(env[:body]) unless env[:body].blank?
        end
      end
      
    end
  end
end
