module ActiveResource

  # Scopes encapsulate a method of adding middleware
  # for individual requests.
  #
  # TODO: It would be nice to store all of the middleware
  # in the scopes so that they clean up after themselves
  # after each request.
  # 
  class Scope
    attr_reader :proxy, :callable, :args

    def initialize(proxy, callable, args)
      @proxy = proxy
      @callable = callable
      @args = args
    end

    # Execute can only be called once, so middlewares
    # are not added more than once.
    #
    def execute
      unless @finished ||= false
        callable.call *args
        @finished = true
      end
    end

    def method_missing(method, *args, &block)

      # Check if method is a scope, if so add it to the chain.
      if proxy.scopes.include?(method)
        proxy.scopes[method].call(self, args)
      else
        # Note: Not sure if this is the best place for execute.
        # It can be called multiple times, but does get called 
        # in the correct order.
        execute
        
        # Take a pass.
        proxy.send(method, *args, &block)
      end
    end
  end
end
