module ActiveResource
  module BaseInstanceMethods
    attr_accessor :attributes #:nodoc:
    attr_accessor :prefix_options #:nodoc:

    # If no schema has been defined for the class (see
    # <tt>ActiveResource::schema=</tt>), the default automatic schema is
    # generated from the current instance's attributes
    def schema
      self.class.schema || self.attributes
    end

    # This is a list of known attributes for this resource. Either
    # gathered from the provided <tt>schema</tt>, or from the attributes
    # set on this instance after it has been fetched from the remote system.
    def known_attributes
      (self.class.known_attributes + self.attributes.keys.map(&:to_s)).uniq
    end


    # Constructor method for \new resources; the optional +attributes+ parameter takes a \hash
    # of attributes for the \new resource.
    #
    # ==== Examples
    #   my_course = Course.new
    #   my_course.name = "Western Civilization"
    #   my_course.lecturer = "Don Trotter"
    #   my_course.save
    #
    #   my_other_course = Course.new(:name => "Philosophy: Reason and Being", :lecturer => "Ralph Cling")
    #   my_other_course.save
    def initialize(attributes = {}, persisted = false)
      @attributes     = {}.with_indifferent_access
      @prefix_options = {}
      @persisted = persisted
      load(attributes)
    end

    # Returns a \clone of the resource that hasn't been assigned an +id+ yet and
    # is treated as a \new resource.
    #
    #   ryan = Person.find(1)
    #   not_ryan = ryan.clone
    #   not_ryan.new?  # => true
    #
    # Any active resource member attributes will NOT be cloned, though all other
    # attributes are. This is to prevent the conflict between any +prefix_options+
    # that refer to the original parent resource and the newly cloned parent
    # resource that does not exist.
    #
    #   ryan = Person.find(1)
    #   ryan.address = StreetAddress.find(1, :person_id => ryan.id)
    #   ryan.hash = {:not => "an ARes instance"}
    #
    #   not_ryan = ryan.clone
    #   not_ryan.new?            # => true
    #   not_ryan.address         # => NoMethodError
    #   not_ryan.hash            # => {:not => "an ARes instance"}
    def clone
      # Clone all attributes except the pk and any nested ARes
      cloned = Hash[attributes.reject {|k,v| k == self.class.primary_key || v.is_a?(ActiveResource::Base)}.map { |k, v| [k, v.clone] }]
      # Form the new resource - bypass initialize of resource with 'new' as that will call 'load' which
      # attempts to convert hashes into member objects and arrays into collections of objects. We want
      # the raw objects to be cloned so we bypass load by directly setting the attributes hash.
      resource = self.class.new({})
      resource.prefix_options = self.prefix_options
      resource.send :instance_variable_set, '@attributes', cloned
      resource
    end


    # Returns +true+ if this object hasn't yet been saved, otherwise, returns +false+.
    #
    # ==== Examples
    #   not_new = Computer.create(:brand => 'Apple', :make => 'MacBook', :vendor => 'MacMall')
    #   not_new.new? # => false
    #
    #   is_new = Computer.new(:brand => 'IBM', :make => 'Thinkpad', :vendor => 'IBM')
    #   is_new.new? # => true
    #
    #   is_new.save
    #   is_new.new? # => false
    #
    def new?
      !persisted?
    end
    alias :new_record? :new?

    # Returns +true+ if this object has been saved, otherwise returns +false+.
    #
    # ==== Examples
    #   persisted = Computer.create(:brand => 'Apple', :make => 'MacBook', :vendor => 'MacMall')
    #   persisted.persisted? # => true
    #
    #   not_persisted = Computer.new(:brand => 'IBM', :make => 'Thinkpad', :vendor => 'IBM')
    #   not_persisted.persisted? # => false
    #
    #   not_persisted.save
    #   not_persisted.persisted? # => true
    #
    def persisted?
      @persisted
    end

    # Gets the <tt>\id</tt> attribute of the resource.
    def id
      attributes[self.class.primary_key]
    end

    # Sets the <tt>\id</tt> attribute of the resource.
    def id=(id)
      attributes[self.class.primary_key] = id
    end

    # Test for equality. Resource are equal if and only if +other+ is the same object or
    # is an instance of the same class, is not <tt>new?</tt>, and has the same +id+.
    #
    # ==== Examples
    #   ryan = Person.create(:name => 'Ryan')
    #   jamie = Person.create(:name => 'Jamie')
    #
    #   ryan == jamie
    #   # => false (Different name attribute and id)
    #
    #   ryan_again = Person.new(:name => 'Ryan')
    #   ryan == ryan_again
    #   # => false (ryan_again is new?)
    #
    #   ryans_clone = Person.create(:name => 'Ryan')
    #   ryan == ryans_clone
    #   # => false (Different id attributes)
    #
    #   ryans_twin = Person.find(ryan.id)
    #   ryan == ryans_twin
    #   # => true
    #
    def ==(other)
      other.equal?(self) || (other.instance_of?(self.class) && other.id == id && other.prefix_options == prefix_options)
    end

    # Tests for equality (delegates to ==).
    def eql?(other)
      self == other
    end

    # Delegates to id in order to allow two resources of the same type and \id to work with something like:
    #   [(a = Person.find 1), (b = Person.find 2)] & [(c = Person.find 1), (d = Person.find 4)] # => [a]
    def hash
      id.hash
    end

    # Duplicates the current resource without saving it.
    #
    # ==== Examples
    #   my_invoice = Invoice.create(:customer => 'That Company')
    #   next_invoice = my_invoice.dup
    #   next_invoice.new? # => true
    #
    #   next_invoice.save
    #   next_invoice == my_invoice # => false (different id attributes)
    #
    #   my_invoice.customer   # => That Company
    #   next_invoice.customer # => That Company
    def dup
      self.class.new.tap do |resource|
        resource.attributes     = @attributes
        resource.prefix_options = @prefix_options
      end
    end

    # Saves (+POST+) or \updates (+PUT+) a resource. Delegates to +create+ if the object is \new,
    # +update+ if it exists. If the response to the \save includes a body, it will be assumed that this body
    # is Json for the final object as it looked after the \save (which would include attributes like +created_at+
    # that weren't part of the original submit).
    #
    # ==== Examples
    #   my_company = Company.new(:name => 'RoleModel Software', :owner => 'Ken Auer', :size => 2)
    #   my_company.new? # => true
    #   my_company.save # sends POST /companies/ (create)
    #
    #   my_company.new? # => false
    #   my_company.size = 10
    #   my_company.save # sends PUT /companies/1 (update)
    def save
      run_callbacks :save do
        new? ? create : update
      end
    end

    # Saves the resource.
    #
    # If the resource is new, it is created via +POST+, otherwise the
    # existing resource is updated via +PUT+.
    #
    # With <tt>save!</tt> validations always run. If any of them fail
    # ActiveResource::ResourceInvalid gets raised, and nothing is POSTed to
    # the remote system.
    # See ActiveResource::Validations for more information.
    #
    # There's a series of callbacks associated with <tt>save!</tt>. If any
    # of the <tt>before_*</tt> callbacks return +false+ the action is
    # cancelled and <tt>save!</tt> raises ActiveResource::ResourceInvalid.
    def save!
      save || raise(ResourceInvalid.new)
    end

    # Deletes the resource from the remote service.
    #
    # ==== Examples
    #   my_id = 3
    #   my_person = Person.find(my_id)
    #   my_person.destroy
    #   Person.find(my_id) # 404 (Resource Not Found)
    #
    #   new_person = Person.create(:name => 'James')
    #   new_id = new_person.id # => 7
    #   new_person.destroy
    #   Person.find(new_id) # 404 (Resource Not Found)
    def destroy
      run_callbacks :destroy do
        # TODO delete(path, params, headers)
        connection.delete(element_path, nil, self.class.headers)
      end
    end

    # Evaluates to <tt>true</tt> if this resource is not <tt>new?</tt> and is
    # found on the remote service. Using this method, you can check for
    # resources that may have been deleted between the object's instantiation
    # and actions on it.
    #
    # ==== Examples
    #   Person.create(:name => 'Theodore Roosevelt')
    #   that_guy = Person.find(:first)
    #   that_guy.exists? # => true
    #
    #   that_lady = Person.new(:name => 'Paul Bean')
    #   that_lady.exists? # => false
    #
    #   guys_id = that_guy.id
    #   Person.delete(guys_id)
    #   that_guy.exists? # => false
    def exists?
      !new? && self.class.exists?(to_param, :params => prefix_options)
    end

    # Returns the serialized string representation of the resource in the configured
    # serialization format specified in ActiveResource::Base.format. The options
    # applicable depend on the configured encoding format.
    def encode(options={})
      send("to_#{self.class.format.extension}", options)
    end

    # A method to \reload the attributes of this object from the remote web service.
    #
    # ==== Examples
    #   my_branch = Branch.find(:first)
    #   my_branch.name # => "Wislon Raod"
    #
    #   # Another client fixes the typo...
    #
    #   my_branch.name # => "Wislon Raod"
    #   my_branch.reload
    #   my_branch.name # => "Wilson Road"
    def reload
      self.load(self.class.find(to_param, :params => @prefix_options).attributes)
    end

    # A method to manually load attributes from a \hash. Recursively loads collections of
    # resources. This method is called in +initialize+ and +create+ when a \hash of attributes
    # is provided.
    #
    # ==== Examples
    #   my_attrs = {:name => 'J&J Textiles', :industry => 'Cloth and textiles'}
    #   my_attrs = {:name => 'Marty', :colors => ["red", "green", "blue"]}
    #
    #   the_supplier = Supplier.find(:first)
    #   the_supplier.name # => 'J&M Textiles'
    #   the_supplier.load(my_attrs)
    #   the_supplier.name('J&J Textiles')
    #
    #   # These two calls are the same as Supplier.new(my_attrs)
    #   my_supplier = Supplier.new
    #   my_supplier.load(my_attrs)
    #
    #   # These three calls are the same as Supplier.create(my_attrs)
    #   your_supplier = Supplier.new
    #   your_supplier.load(my_attrs)
    #   your_supplier.save
    def load(attributes, remove_root = false)
      raise ArgumentError, "expected an attributes Hash, got #{attributes.inspect}" unless attributes.is_a?(Hash)
      @prefix_options, attributes = split_options(attributes)

      if attributes.keys.size == 1
        remove_root = self.class.element_name == attributes.keys.first.to_s
      end

      attributes = Middleware::Formats.remove_root(attributes) if remove_root

      attributes.each do |key, value|
        @attributes[key.to_s] =
          case value
          when Array
            resource = nil
            value.map do |attrs|
              if attrs.is_a?(Hash)
                resource ||= find_or_create_resource_for_collection(key)
                resource.new(attrs)
              else
                attrs.duplicable? ? attrs.dup : attrs
              end
            end
          when Hash
            resource = find_or_create_resource_for(key)
            resource.new(value)
          else
            value.duplicable? ? value.dup : value
          end
      end
      self
    end

    # Updates a single attribute and then saves the object.
    #
    # Note: <tt>Unlike ActiveRecord::Base.update_attribute</tt>, this method <b>is</b>
    # subject to normal validation routines as an update sends the whole body
    # of the resource in the request. (See Validations).
    #
    # As such, this method is equivalent to calling update_attributes with a single attribute/value pair.
    #
    # If the saving fails because of a connection or remote service error, an
    # exception will be raised. If saving fails because the resource is
    # invalid then <tt>false</tt> will be returned.
    def update_attribute(name, value)
      self.send("#{name}=".to_sym, value)
      self.save
    end

    # Updates this resource with all the attributes from the passed-in Hash
    # and requests that the record be saved.
    #
    # If the saving fails because of a connection or remote service error, an
    # exception will be raised. If saving fails because the resource is
    # invalid then <tt>false</tt> will be returned.
    #
    # Note: Though this request can be made with a partial set of the
    # resource's attributes, the full body of the request will still be sent
    # in the save request to the remote service.
    def update_attributes(attributes)
      load(attributes, false) && save
    end

    # For checking <tt>respond_to?</tt> without searching the attributes (which is faster).
    alias_method :respond_to_without_attributes?, :respond_to?

    # A method to determine if an object responds to a message (e.g., a method call). In Active Resource, a Person object with a
    # +name+ attribute can answer <tt>true</tt> to <tt>my_person.respond_to?(:name)</tt>, <tt>my_person.respond_to?(:name=)</tt>, and
    # <tt>my_person.respond_to?(:name?)</tt>.
    def respond_to?(method, include_priv = false)
      method_name = method.to_s
      if attributes.nil?
        super
      elsif known_attributes.include?(method_name)
        true
      elsif method_name =~ /(?:=|\?)$/ && attributes.include?($`)
        true
      else
        # super must be called at the end of the method, because the inherited respond_to?
        # would return true for generated readers, even if the attribute wasn't present
        super
      end
    end

    def to_json(options={})
      super({ :root => self.class.element_name }.merge(options))
    end

    def to_xml(options={})
      super({ :root => self.class.element_name }.merge(options))
    end

    # Get class scopes
    def scopes
      self.class.scopes
    end

    protected
    def connection(refresh = false)
      self.class.connection(refresh)
    end

    # Update the resource on the remote service.
    def update
      run_callbacks :update do
        # TODO put(path, body, headers)
        connection.put(element_path(prefix_options), encode).tap do |response|
          load_attributes_from_response(response)
        end
      end
    end

    # Create (i.e., \save to the remote service) the \new resource.
    def create
      run_callbacks :create do
        # TODO post(path, body, headers)
        connection.post(collection_path, encode).tap do |response|
          self.id = id_from_response(response)
          load_attributes_from_response(response)
        end
      end
    end

    def load_attributes_from_response(response)
      if (response_code_allows_body?(response.status) &&
          (response.headers['Content-Length'].nil? || response.headers['Content-Length'] != "0") &&
          !response.body.nil?)
        load(response.body, true)
        @persisted = true
      end
    end

    # Takes a response from a typical create post and pulls the ID out
    def id_from_response(response)
      # TODO: Shouldn't headers be accessed by response.headers['Location']?
      response['Location'][/\/([^\/]*?)(\.\w+)?$/, 1] if response['Location']
    end

    def element_path(options = nil)
      self.class.element_path(to_param, options || prefix_options)
    end

    def new_element_path
      self.class.new_element_path(prefix_options)
    end

    def collection_path(options = nil)
      self.class.collection_path(options || prefix_options)
    end

    private

    def read_attribute_for_serialization(n)
      attributes[n]
    end

    # Determine whether the response is allowed to have a body per HTTP 1.1 spec section 4.4.1
    def response_code_allows_body?(c)
      !((100..199).include?(c) || [204,304].include?(c))
    end

    # Tries to find a resource for a given collection name; if it fails, then the resource is created
    def find_or_create_resource_for_collection(name)
      return reflections[name.to_sym].klass if reflections.key?(name.to_sym)
      find_or_create_resource_for(ActiveSupport::Inflector.singularize(name.to_s))
    end

    # Tries to find a resource in a non empty list of nested modules
    # if it fails, then the resource is created
    def find_or_create_resource_in_modules(resource_name, module_names)
      receiver = Object
      namespaces = module_names[0, module_names.size-1].map do |module_name|
        receiver = receiver.const_get(module_name)
      end
      const_args = [resource_name, false]
      if namespace = namespaces.reverse.detect { |ns| ns.const_defined?(*const_args) }
        namespace.const_get(*const_args)
      else
        create_resource_for(resource_name)
      end
    end

    # Tries to find a resource for a given name; if it fails, then the resource is created
    def find_or_create_resource_for(name)
      return reflections[name.to_sym].klass if reflections.key?(name.to_sym)
      resource_name = name.to_s.camelize

      const_args = [resource_name, false]
      if self.class.const_defined?(*const_args)
        self.class.const_get(*const_args)
      else
        ancestors = self.class.name.split("::")
        if ancestors.size > 1
          find_or_create_resource_in_modules(resource_name, ancestors)
        else
          if Object.const_defined?(*const_args)
            Object.const_get(*const_args)
          else
            create_resource_for(resource_name)
          end
        end
      end
    end

    # Create and return a class definition for a resource inside the current resource
    def create_resource_for(resource_name)
      resource = self.class.const_set(resource_name, Class.new(ActiveResource::Base))
      resource.prefix = self.class.prefix
      resource.site   = self.class.site
      resource
    end

    def split_options(options = {})
      self.class.__send__(:split_options, options)
    end

    def method_missing(method_symbol, *arguments) #:nodoc:
      method_name = method_symbol.to_s

      if method_name =~ /(=|\?)$/
        case $1
        when "="
          attributes[$`] = arguments.first
        when "?"
          attributes[$`]
        end
      else
        return attributes[method_name] if attributes.include?(method_name)
        # not set right now but we know about it
        return nil if known_attributes.include?(method_name)
        super
      end
    end

  end
end
