module ActiveResource
  module BaseClassMethods
    # Creates a schema for this resource - setting the attributes that are
    # known prior to fetching an instance from the remote system.
    #
    # The schema helps define the set of <tt>known_attributes</tt> of the
    # current resource.
    #
    # There is no need to specify a schema for your Active Resource. If
    # you do not, the <tt>known_attributes</tt> will be guessed from the
    # instance attributes returned when an instance is fetched from the
    # remote system.
    #
    # example:
    #   class Person < ActiveResource::Base
    #     schema do
    #       # define each attribute separately
    #       attribute 'name', :string
    #   
    #       # or use the convenience methods and pass >=1 attribute names
    #       string  'eye_color', 'hair_color'
    #       integer 'age'
    #       float   'height', 'weight'
    #   
    #       # unsupported types should be left as strings
    #       # overload the accessor methods if you need to convert them
    #       attribute 'created_at', 'string'
    #     end
    #   end
    #
    #   p = Person.new
    #   p.respond_to? :name   # => true
    #   p.respond_to? :age    # => true
    #   p.name                # => nil
    #   p.age                 # => nil
    #
    #   j = Person.find_by_name('John')
    #   <person><name>John</name><age>34</age><num_children>3</num_children></person>
    #   j.respond_to? :name   # => true
    #   j.respond_to? :age    # => true
    #   j.name                # => 'John'
    #   j.age                 # => '34'  # note this is a string!
    #   j.num_children        # => '3'  # note this is a string!
    #
    #   p.num_children        # => NoMethodError
    #
    # Attribute-types must be one of: <tt>string, integer, float</tt>
    #
    # Note: at present the attribute-type doesn't do anything, but stay
    # tuned...
    # Shortly it will also *cast* the value of the returned attribute.
    # ie:
    # j.age                 # => 34   # cast to an integer
    # j.weight              # => '65' # still a string!
    #
    def schema(&block)
      if block_given?
        schema_definition = Schema.new
        schema_definition.instance_eval(&block)

        # skip out if we didn't define anything
        return unless schema_definition.attrs.present?

        @schema ||= {}.with_indifferent_access
        @known_attributes ||= []

        schema_definition.attrs.each do |k,v|
          @schema[k] = v
          @known_attributes << k
        end

        schema
      else
        @schema ||= nil
      end
    end

    # Alternative, direct way to specify a <tt>schema</tt> for this
    # Resource. <tt>schema</tt> is more flexible, but this is quick
    # for a very simple schema.
    #
    # Pass the schema as a hash with the keys being the attribute-names
    # and the value being one of the accepted attribute types (as defined
    # in <tt>schema</tt>)
    #
    # example:
    #
    #   class Person < ActiveResource::Base
    #     schema = {'name' => :string, 'age' => :integer }
    #   end
    #
    # The keys/values can be strings or symbols. They will be converted to
    # strings.
    #
    def schema=(the_schema)
      unless the_schema.present?
        # purposefully nulling out the schema
        @schema = nil
        @known_attributes = []
        return
      end

      raise ArgumentError, "Expected a hash" unless the_schema.kind_of? Hash

      schema do
        the_schema.each {|k,v| attribute(k,v) }
      end
    end

    # Returns the list of known attributes for this resource, gathered
    # from the provided <tt>schema</tt>
    # Attributes that are known will cause your resource to return 'true'
    # when <tt>respond_to?</tt> is called on them. A known attribute will
    # return nil if not set (rather than <tt>MethodNotFound</tt>); thus
    # known attributes can be used with <tt>validates_presence_of</tt>
    # without a getter-method.
    def known_attributes
      @known_attributes ||= []
    end

    # Set the adapter to use.
    #
    # TODO finish docs.
    #
    def adapter=(adapter)
      @adapter = adapter
    end

    def adapter
      @adapter ||= :net_http
    end

    # Gets the URI of the REST resources to map for this class. The site variable is required for
    # Active Resource's mapping to work.
    def site
      # Not using superclass_delegating_reader because don't want subclasses to modify superclass instance
      #
      # With superclass_delegating_reader
      #
      #   Parent.site = 'https://anonymous@test.com'
      #   Subclass.site # => 'https://anonymous@test.com'
      #   Subclass.site.user = 'david'
      #   Parent.site # => 'https://david@test.com'
      #
      # Without superclass_delegating_reader (expected behavior)
      #
      #   Parent.site = 'https://anonymous@test.com'
      #   Subclass.site # => 'https://anonymous@test.com'
      #   Subclass.site.user = 'david' # => TypeError: can't modify frozen object
      #
      if defined?(@site)
        @site
      elsif superclass != Object && superclass.site
        superclass.site.dup.freeze
      end
    end

    # Sets the URI of the REST resources to map for this class to the value in the +site+ argument.
    # The site variable is required for Active Resource's mapping to work.
    def site=(site)
      @connection = nil
      if site.nil?
        @site = nil
      else
        @site = create_site_uri_from(site)
        @user = URI.parser.unescape(@site.user) if @site.user
        @password = URI.parser.unescape(@site.password) if @site.password
      end
    end

    # Gets the \proxy variable if a proxy is required
    def proxy
      # Not using superclass_delegating_reader. See +site+ for explanation
      if defined?(@proxy)
        @proxy
      elsif superclass != Object && superclass.proxy
        superclass.proxy.dup.freeze
      end
    end

    # Sets the URI of the http proxy to the value in the +proxy+ argument.
    def proxy=(proxy)
      @connection = nil
      @proxy = proxy.nil? ? nil : create_proxy_uri_from(proxy)
    end

    # Gets the \user for REST HTTP authentication.
    def user
      # Not using superclass_delegating_reader. See +site+ for explanation
      if defined?(@user)
        @user
      elsif superclass != Object && superclass.user
        superclass.user.dup.freeze
      end
    end

    # Sets the \user for REST HTTP authentication.
    def user=(user)
      @connection = nil
      @user = user
    end

    # Gets the \password for REST HTTP authentication.
    def password
      # Not using superclass_delegating_reader. See +site+ for explanation
      if defined?(@password)
        @password
      elsif superclass != Object && superclass.password
        superclass.password.dup.freeze
      end
    end

    # Sets the \password for REST HTTP authentication.
    def password=(password)
      @connection = nil
      @password = password
    end

    def auth_type
      if defined?(@auth_type)
        @auth_type
      end
    end

    def auth_type=(auth_type)
      @connection = nil
      @auth_type = auth_type
    end

    # Sets the format that attributes are sent and received in from a mime type reference:
    #
    #   Person.format = :json
    #   Person.find(1) # => GET /people/1.json
    #
    #   Person.format = ActiveResource::Middleware::Formats::XmlFormat
    #   Person.find(1) # => GET /people/1.xml
    #
    # Default format is <tt>:json</tt>.
    def format=(mime_type_reference_or_format)
      format = mime_type_reference_or_format.is_a?(Symbol) ?
        ActiveResource::Middleware::Formats[mime_type_reference_or_format] : mime_type_reference_or_format

      self._format = format
    end

    # Returns the current format, default is ActiveResource::Middleware::Formats::JsonFormat.
    def format
      self._format || ActiveResource::Middleware::Formats::JsonFormat
    end

    # Sets the number of seconds after which requests to the REST API should time out.
    def timeout=(timeout)
      @connection = nil
      @timeout = timeout
    end

    # Gets the number of seconds after which requests to the REST API should time out.
    def timeout
      if defined?(@timeout)
        @timeout
      elsif superclass != Object && superclass.timeout
        superclass.timeout
      end
    end

    # Options that will get applied to an SSL connection.
    #
    # * <tt>:key</tt> - An OpenSSL::PKey::RSA or OpenSSL::PKey::DSA object.
    # * <tt>:cert</tt> - An OpenSSL::X509::Certificate object as client certificate
    # * <tt>:ca_file</tt> - Path to a CA certification file in PEM format. The file can contain several CA certificates.
    # * <tt>:ca_path</tt> - Path of a CA certification directory containing certifications in PEM format.
    # * <tt>:verify_mode</tt> - Flags for server the certification verification at beginning of SSL/TLS session. (OpenSSL::SSL::VERIFY_NONE or OpenSSL::SSL::VERIFY_PEER is acceptable)
    # * <tt>:verify_callback</tt> - The verify callback for the server certification verification.
    # * <tt>:verify_depth</tt> - The maximum depth for the certificate chain verification.
    # * <tt>:cert_store</tt> - OpenSSL::X509::Store to verify peer certificate.
    # * <tt>:ssl_timeout</tt> -The SSL timeout in seconds.
    def ssl_options=(opts={})
      @connection   = nil
      @ssl_options  = opts
    end

    # Returns the SSL options hash.
    def ssl_options
      if defined?(@ssl_options)
        @ssl_options
      elsif superclass != Object && superclass.ssl_options
        superclass.ssl_options
      end
    end

    # exposes the current connection bulider
    # middleware.swap(Faraday::Adapter::NetHttp, Faraday::Adapter::NetHttpPersistent)
    # this may not stick around, it presents two ways of changing the adapter and format
    def middleware
      if connection.builder.locked?
        connection(true).builder
      else
        connection.builder
      end
    end

    # Scopes defined for this class
    def scopes
      @scopes ||= {}
    end

    def scope(name, callable)
      name = name.to_sym

      # Create scope.
      scopes[name] = lambda do |proxy, args|
        ActiveResource::RequestScope.new(proxy, callable, args)
      end

      # Define scope method.
      singleton_class.send :define_method, name do |*args|
        scopes[name].call(self, args)
      end
    end

    # An instance of ActiveResource::Connection that is the base \connection to the remote service.
    # The +refresh+ parameter toggles whether or not the \connection is refreshed at every request
    # or not (defaults to <tt>false</tt>).
    def connection(refresh = false)
      if defined?(@connection) || superclass == Object
        if refresh || @connection.nil? || adapter == :test
          @connection = Faraday.new(site) do |builder|
            # Fill in other options here on builder if possible or use a hash
            # in the args to Faraday.new
            #
            # @connection.proxy = proxy if proxy
            # @connection.user = user if user
            # @connection.password = password if password
            # @connection.auth_type = auth_type if auth_type
            # @connection.timeout = timeout if timeout
            # @connection.ssl_options = ssl_options if ssl_options

            builder.use ActiveResource::Middleware::Rails

            builder.basic_auth(user, password) if user || password

            # The raised errors need access to the response and
            # middleware does not have access to the response object
            # yet.
            #
            builder.use(ActiveResource::Response::RaiseError)

            builder.use format

            builder.use ActiveResource::Middleware::Logger

            # The adapter needs to be set last. It would make sense to set
            # put the RaiseErrors right before.
            unless adapter == :test
              builder.adapter adapter
            else
              builder.adapter adapter, ActiveResource::Stubs.stubs
            end
          end
        end
        @connection
      else
        superclass.connection
      end
    end

    def headers
      @headers ||= {}

      if superclass != Object && superclass.headers
        @headers = superclass.headers.merge(@headers)
      else
        @headers
      end
    end

    attr_writer :element_name

    def element_name
      @element_name ||= model_name.element
    end

    attr_writer :collection_name

    def collection_name
      @collection_name ||= ActiveSupport::Inflector.pluralize(element_name)
    end

    attr_writer :primary_key

    def primary_key
      @primary_key ||= 'id'
    end

    # Gets the \prefix for a resource's nested URL (e.g., <tt>prefix/collectionname/1.json</tt>)
    # This method is regenerated at runtime based on what the \prefix is set to.
    def prefix(options={})
      default = site.path
      default << '/' unless default[-1..-1] == '/'
      # generate the actual method based on the current site path
      self.prefix = default
      prefix(options)
    end

    # An attribute reader for the source string for the resource path \prefix. This
    # method is regenerated at runtime based on what the \prefix is set to.
    def prefix_source
      prefix # generate #prefix and #prefix_source methods first
      prefix_source
    end

    # Sets the \prefix for a resource's nested URL (e.g., <tt>prefix/collectionname/1.json</tt>).
    # Default value is <tt>site.path</tt>.
    def prefix=(value = '/')
      # Replace :placeholders with '#{embedded options[:lookups]}'
      prefix_call = value.gsub(/:\w+/) { |key| "\#{URI.parser.escape options[#{key}].to_s}" }

      # Clear prefix parameters in case they have been cached
      @prefix_parameters = nil

      silence_warnings do
        # Redefine the new methods.
        instance_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
            def prefix_source() "#{value}" end
            def prefix(options={}) "#{prefix_call}" end
        RUBY_EVAL
      end
    rescue Exception => e
      logger.error "Couldn't set prefix: #{e}\n  #{code}" if logger
      raise
    end

    alias_method :set_prefix, :prefix=  #:nodoc:

    alias_method :set_element_name, :element_name=  #:nodoc:
    alias_method :set_collection_name, :collection_name=  #:nodoc:

    # Gets the element path for the given ID in +id+. If the +query_options+ parameter is omitted, Rails
    # will split from the \prefix options.
    #
    # ==== Options
    # +prefix_options+ - A \hash to add a \prefix to the request for nested URLs (e.g., <tt>:account_id => 19</tt>
    # would yield a URL like <tt>/accounts/19/purchases.json</tt>).
    #
    # +query_options+ - A \hash to add items to the query string for the request.
    #
    # ==== Examples
    #   Post.element_path(1)
    #   # => /posts/1.json
    #
    #   class Comment < ActiveResource::Base
    #     self.site = "https://37s.sunrise.com/posts/:post_id"
    #   end
    #
    #   Comment.element_path(1, :post_id => 5)
    #   # => /posts/5/comments/1.json
    #
    #   Comment.element_path(1, :post_id => 5, :active => 1)
    #   # => /posts/5/comments/1.json?active=1
    #
    #   Comment.element_path(1, {:post_id => 5}, {:active => 1})
    #   # => /posts/5/comments/1.json?active=1
    #
    def element_path(id, prefix_options = {}, query_options = nil)
      check_prefix_options(prefix_options)

      prefix_options, query_options = split_options(prefix_options) if query_options.nil?
      "#{prefix(prefix_options)}#{collection_name}/#{URI.parser.escape id.to_s}.#{format.extension}#{query_string(query_options)}"
    end

    # Gets the new element path for REST resources.
    #
    # ==== Options
    # * +prefix_options+ - A hash to add a prefix to the request for nested URLs (e.g., <tt>:account_id => 19</tt>
    # would yield a URL like <tt>/accounts/19/purchases/new.json</tt>).
    #
    # ==== Examples
    #   Post.new_element_path
    #   # => /posts/new.json
    #
    #   class Comment < ActiveResource::Base
    #     self.site = "https://37s.sunrise.com/posts/:post_id"
    #   end
    #
    #   Comment.collection_path(:post_id => 5)
    #   # => /posts/5/comments/new.json
    def new_element_path(prefix_options = {})
      "#{prefix(prefix_options)}#{collection_name}/new.#{format.extension}"
    end

    # Gets the collection path for the REST resources. If the +query_options+ parameter is omitted, Rails
    # will split from the +prefix_options+.
    #
    # ==== Options
    # * +prefix_options+ - A hash to add a prefix to the request for nested URLs (e.g., <tt>:account_id => 19</tt>
    #   would yield a URL like <tt>/accounts/19/purchases.json</tt>).
    # * +query_options+ - A hash to add items to the query string for the request.
    #
    # ==== Examples
    #   Post.collection_path
    #   # => /posts.json
    #
    #   Comment.collection_path(:post_id => 5)
    #   # => /posts/5/comments.json
    #
    #   Comment.collection_path(:post_id => 5, :active => 1)
    #   # => /posts/5/comments.json?active=1
    #
    #   Comment.collection_path({:post_id => 5}, {:active => 1})
    #   # => /posts/5/comments.json?active=1
    #
    def collection_path(prefix_options = {}, query_options = nil)
      check_prefix_options(prefix_options)
      prefix_options, query_options = split_options(prefix_options) if query_options.nil?
      "#{prefix(prefix_options)}#{collection_name}.#{format.extension}#{query_string(query_options)}"
    end

    alias_method :set_primary_key, :primary_key=  #:nodoc:

  end
end
