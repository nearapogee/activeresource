module ActiveResource
  class ConnectionError < StandardError # :nodoc:
    attr_reader :response

    def initialize(env, message = nil)
      @response = env[:response]
      @message  = message
    end

    def to_s
      message = "Failed."
      message << "  Response code = #{response.status}." if response.respond_to?(:status)
      # TODO net/http has a message for every status code. Do we want to implement this?
      message << "  Response message = #{response.message}." if response.respond_to?(:message)
      message
    end
  end

  # Raised when a Timeout::Error occurs.
  class TimeoutError < ConnectionError
    def initialize(message)
      @message = message
    end
    def to_s; @message ;end
  end

  # Raised when a OpenSSL::SSL::SSLError occurs.
  class SSLError < ConnectionError
    def initialize(message)
      @message = message
    end
    def to_s; @message ;end
  end

  # 3xx Redirection
  class Redirection < ConnectionError # :nodoc:
    def to_s
      response.headers['Location'] ? "#{super} => #{response.headers['Location']}" : super
    end
  end

  class MissingPrefixParam < ArgumentError # :nodoc:
  end

  # 4xx Client Error
  class ClientError < ConnectionError # :nodoc:
  end

  # 400 Bad Request
  class BadRequest < ClientError # :nodoc:
  end

  # 401 Unauthorized
  class UnauthorizedAccess < ClientError # :nodoc:
  end

  # 403 Forbidden
  class ForbiddenAccess < ClientError # :nodoc:
  end

  # 404 Not Found
  class ResourceNotFound < ClientError # :nodoc:
  end

  # 409 Conflict
  class ResourceConflict < ClientError # :nodoc:
  end

  # 410 Gone
  class ResourceGone < ClientError # :nodoc:
  end

  # 5xx Server Error
  class ServerError < ConnectionError # :nodoc:
  end

  # 405 Method Not Allowed
  class MethodNotAllowed < ClientError # :nodoc:
    def allowed_methods
      @response.headers['Allow'].split(',').map { |verb| verb.strip.downcase.to_sym }
    end
  end
end
