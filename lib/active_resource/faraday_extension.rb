module Faraday
  class Response
    # ActiveResource's old connection class supported the code method
    # now we're returning a faraday response, and warning about the deprication
    def code
      ActiveSupport::Deprecation.warn('Calling code on response is depricated, please use status')
      status
    end
  end
end