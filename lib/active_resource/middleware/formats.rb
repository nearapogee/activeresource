module ActiveResource
  module Middleware
    module Formats
      autoload :XmlFormat, 'active_resource/middleware/formats/xml_format'
      autoload :JsonFormat, 'active_resource/middleware/formats/json_format'

      # Lookup the format class from a mime type reference symbol. Example:
      #
      #   ActiveResource::Middleware::Formats[:xml]  # => ActiveResource::Middleware::Formats::XmlFormat
      #   ActiveResource::Middleware::Formats[:json] # => ActiveResource::Middleware::Formats::JsonFormat
      def self.[](mime_type_reference)
        ActiveResource::Middleware::Formats.const_get(ActiveSupport::Inflector.camelize(mime_type_reference.to_s) + "Format")
      end

      def self.remove_root(data)
        if data.is_a?(Hash) && data.keys.size == 1
          data.values.first
        else
          data
        end
      end
    end
  end
end
