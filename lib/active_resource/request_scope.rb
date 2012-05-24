module ActiveResource

  # Scopes encapsulate a method of adding middleware
  # for individual requests.
  #
  class RequestScope
    module ConnectionMethods
      def connection
        @connection ||= proxy.send(:connection).dup
      end
    end

    attr_reader :proxy

    def initialize(proxy, callable, args)
      @proxy = proxy
      if proxy.class != RequestScope
        extend ActiveResource::ResourceClassMethods
        extend RequestScope::ConnectionMethods
      end
      connection.builder.instance_exec *args, &callable
    end

    def method_missing(method, *args, &block)
      if proxy.scopes.include?(method)
        proxy.scopes[method].call(self, args)
      else
        proxy.send(method, *args, &block)
      end
    end
  end
end
