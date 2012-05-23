module ActiveResource
  module ResourceClassMethods
    # Builds a new, unsaved record using the default values from the remote server so
    # that it can be used with RESTful forms.
    #
    # ==== Options
    # * +attributes+ - A hash that overrides the default values from the server.
    #
    # Returns the new resource instance.
    #
    def build(attributes = {})
      # TODO get(path, params, headers)
      attrs = connection.get("#{new_element_path}").body.merge(attributes)
      self.new(attrs)
    end

    # Creates a new resource instance and makes a request to the remote service
    # that it be saved, making it equivalent to the following simultaneous calls:
    #
    #   ryan = Person.new(:first => 'ryan')
    #   ryan.save
    #
    # Returns the newly created resource. If a failure has occurred an
    # exception will be raised (see <tt>save</tt>). If the resource is invalid and
    # has not been saved then <tt>valid?</tt> will return <tt>false</tt>,
    # while <tt>new?</tt> will still return <tt>true</tt>.
    #
    # ==== Examples
    #   Person.create(:name => 'Jeremy', :email => 'myname@nospam.com', :enabled => true)
    #   my_person = Person.find(:first)
    #   my_person.email # => myname@nospam.com
    #
    #   dhh = Person.create(:name => 'David', :email => 'dhh@nospam.com', :enabled => true)
    #   dhh.valid? # => true
    #   dhh.new?   # => false
    #
    #   # We'll assume that there's a validation that requires the name attribute
    #   that_guy = Person.create(:name => '', :email => 'thatguy@nospam.com', :enabled => true)
    #   that_guy.valid? # => false
    #   that_guy.new?   # => true
    def create(attributes = {})
      self.new(attributes).tap { |resource| resource.save }
    end

    # Core method for finding resources. Used similarly to Active Record's +find+ method.
    #
    # ==== Arguments
    # The first argument is considered to be the scope of the query. That is, how many
    # resources are returned from the request. It can be one of the following.
    #
    # * <tt>:one</tt> - Returns a single resource.
    # * <tt>:first</tt> - Returns the first resource found.
    # * <tt>:last</tt> - Returns the last resource found.
    # * <tt>:all</tt> - Returns every resource that matches the request.
    #
    # ==== Options
    #
    # * <tt>:from</tt> - Sets the path or custom method that resources will be fetched from.
    # * <tt>:params</tt> - Sets query and \prefix (nested URL) parameters.
    #
    # ==== Examples
    #   Person.find(1)
    #   # => GET /people/1.json
    #
    #   Person.find(:all)
    #   # => GET /people.json
    #
    #   Person.find(:all, :params => { :title => "CEO" })
    #   # => GET /people.json?title=CEO
    #
    #   Person.find(:first, :from => :managers)
    #   # => GET /people/managers.json
    #
    #   Person.find(:last, :from => :managers)
    #   # => GET /people/managers.json
    #
    #   Person.find(:all, :from => "/companies/1/people.json")
    #   # => GET /companies/1/people.json
    #
    #   Person.find(:one, :from => :leader)
    #   # => GET /people/leader.json
    #
    #   Person.find(:all, :from => :developers, :params => { :language => 'ruby' })
    #   # => GET /people/developers.json?language=ruby
    #
    #   Person.find(:one, :from => "/companies/1/manager.json")
    #   # => GET /companies/1/manager.json
    #
    #   StreetAddress.find(1, :params => { :person_id => 1 })
    #   # => GET /people/1/street_addresses/1.json
    #
    # == Failure or missing data
    # A failure to find the requested object raises a ResourceNotFound
    # exception if the find was called with an id.
    # With any other scope, find returns nil when no data is returned.
    #
    #   Person.find(1)
    #   # => raises ResourceNotFound
    #
    #   Person.find(:all)
    #   Person.find(:first)
    #   Person.find(:last)
    #   # => nil
    def find(*arguments)
      scope   = arguments.slice!(0)
      options = arguments.slice!(0) || {}

      case scope
      when :all   then find_every(options)
      when :first then find_every(options).first
      when :last  then find_every(options).last
      when :one   then find_one(options)
      else             find_single(scope, options)
      end
    end


    # A convenience wrapper for <tt>find(:first, *args)</tt>. You can pass
    # in all the same arguments to this method as you can to
    # <tt>find(:first)</tt>.
    def first(*args)
      find(:first, *args)
    end

    # A convenience wrapper for <tt>find(:last, *args)</tt>. You can pass
    # in all the same arguments to this method as you can to
    # <tt>find(:last)</tt>.
    def last(*args)
      find(:last, *args)
    end

    # This is an alias for find(:all). You can pass in all the same
    # arguments to this method as you can to <tt>find(:all)</tt>
    def all(*args)
      find(:all, *args)
    end


    # Deletes the resources with the ID in the +id+ parameter.
    #
    # ==== Options
    # All options specify \prefix and query parameters.
    #
    # ==== Examples
    #   Event.delete(2) # sends DELETE /events/2
    #
    #   Event.create(:name => 'Free Concert', :location => 'Community Center')
    #   my_event = Event.find(:first) # let's assume this is event with ID 7
    #   Event.delete(my_event.id) # sends DELETE /events/7
    #
    #   # Let's assume a request to events/5/cancel.json
    #   Event.delete(params[:id]) # sends DELETE /events/5
    def delete(id, options = {})
      # TODO delete(path, params, headers)
      connection.delete(element_path(id, options))
    end

    # Asserts the existence of a resource, returning <tt>true</tt> if the resource is found.
    #
    # ==== Examples
    #   Note.create(:title => 'Hello, world.', :body => 'Nothing more for now...')
    #   Note.exists?(1) # => true
    #
    #   Note.exists(1349) # => false
    def exists?(id, options = {})
      if id
        prefix_options, query_options = split_options(options[:params])
        path = element_path(id, prefix_options, query_options)
        # TODO head(path, params, headers)
        response = connection.head(path, headers)
        response.status.to_i == 200
      end
      # id && !find_single(id, options).nil?
    rescue ActiveResource::ResourceNotFound, ActiveResource::ResourceGone
      false
    end

    private

    def check_prefix_options(prefix_options)
      p_options = HashWithIndifferentAccess.new(prefix_options)
      prefix_parameters.each do |p|
        raise(MissingPrefixParam, "#{p} prefix_option is missing") if p_options[p].blank?
      end
    end

    # Find every resource
    def find_every(options)
      begin
        case from = options[:from]
        when Symbol
          # TODO: this calls CustomMethods#get, should(?) be Faraday get
          # TODO get(path, params, headers)
          instantiate_collection(get(from, options[:params]))
        when String
          path = "#{from}#{query_string(options[:params])}"
          # TODO get(path, params, headers)
          instantiate_collection( (connection.get(path, nil, headers).body || []))
        else
          prefix_options, query_options = split_options(options[:params])
          path = collection_path(prefix_options, query_options)
          # TODO get(path, params, headers)
          instantiate_collection( (connection.get(path, nil, headers).body || []), prefix_options )
        end
      rescue ActiveResource::ResourceNotFound
        # Swallowing ResourceNotFound exceptions and return nil - as per
        # ActiveRecord.
        []
      end
    end

    # Find a single resource from a one-off URL
    def find_one(options)
      case from = options[:from]
      when Symbol
        # TODO: this calls CustomMethods#get, should(?) be Faraday get
        # TODO get(path, params, headers)
        instantiate_record(get(from, options[:params]))
      when String
        path = "#{from}#{query_string(options[:params])}"
        # TODO get(path, params, headers)
        instantiate_record(connection.get(path, nil, headers).body)
      end
    end

    # Find a single resource from the default URL
    def find_single(scope, options)
      prefix_options, query_options = split_options(options[:params])
      path = element_path(scope, prefix_options, query_options)
      # TODO get(path, params, headers)
      instantiate_record(connection.get(path, nil, headers).body, prefix_options)
    end

    def instantiate_collection(collection, prefix_options = {})
      collection.collect! { |record| instantiate_record(record, prefix_options) }
    end

    def instantiate_record(record, prefix_options = {})
      new(record, true).tap do |resource|
        resource.prefix_options = prefix_options
      end
    end


    # Accepts a URI and creates the site URI from that.
    def create_site_uri_from(site)
      site.is_a?(URI) ? site.dup : URI.parse(site)
    end

    # Accepts a URI and creates the proxy URI from that.
    def create_proxy_uri_from(proxy)
      proxy.is_a?(URI) ? proxy.dup : URI.parse(proxy)
    end

    # contains a set of the current prefix parameters.
    def prefix_parameters
      @prefix_parameters ||= prefix_source.scan(/:\w+/).map { |key| key[1..-1].to_sym }.to_set
    end

    # Builds the query string for the request.
    def query_string(options)
      "?#{options.to_query}" unless options.nil? || options.empty?
    end

    # split an option hash into two hashes, one containing the prefix options,
    # and the other containing the leftovers.
    def split_options(options = {})
      prefix_options, query_options = {}, {}

      (options || {}).each do |key, value|
        next if key.blank? || !key.respond_to?(:to_sym)
        (prefix_parameters.include?(key.to_sym) ? prefix_options : query_options)[key.to_sym] = value
      end

      [ prefix_options, query_options ]
    end
  end
end
