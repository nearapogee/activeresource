require 'abstract_unit'
require "fixtures/person"
require "fixtures/street_address"

class FormatTest < ActiveSupport::TestCase
  def setup
    @matz  = { :id => 1, :name => 'Matz' }
    @david = { :id => 2, :name => 'David' }

    @programmers = [ @matz, @david ]
  end

  def test_formats_on_single_element
    [ :json, :xml ].each do |format|
      using_format(Person, format) do
        ActiveResource::Stubs.clear
        Person.connection(true)
        ActiveResource::Stubs.add do |stub|
          stub.get("/people/1.#{format}") {[200, {}, ActiveResource::Middleware::Formats[format].encode(@david)]}
        end
        assert_equal @david[:name], Person.find(1).name
      end
    end
  end

  def test_formats_on_collection
    [ :json, :xml ].each do |format|
      using_format(Person, format) do
        ActiveResource::Stubs.clear
        Person.connection(true)
        ActiveResource::Stubs.add do |stub|
          stub.get("/people.#{format}") {[200, {}, ActiveResource::Middleware::Formats[format].encode(@programmers)]}
        end
        remote_programmers = Person.find(:all)
        assert_equal 2, remote_programmers.size
        assert remote_programmers.find { |p| p.name == 'David' }
      end
    end
  end

  def test_formats_on_custom_collection_method
    [ :json, :xml ].each do |format|
      using_format(Person, format) do
        ActiveResource::Stubs.clear
        Person.connection(true)
        ActiveResource::Stubs.add do |stub|
          stub.get("/people/retrieve.#{format}?name=David") {[200, {}, ActiveResource::Middleware::Formats[format].encode([@david])]}
        end
        remote_programmers = Person.get(:retrieve, :name => 'David')
        assert_equal 1, remote_programmers.size
        assert_equal @david[:id], remote_programmers[0]['id']
        assert_equal @david[:name], remote_programmers[0]['name']
      end
    end
  end

  def test_formats_on_custom_element_method
    [ :json, :xml ].each do |format|
      using_format(Person, format) do
        david = (format == :json ? { :person => @david } : @david)
        ActiveResource::Stubs.clear
        Person.connection(true)
        ActiveResource::Stubs.add do |stub|
          stub.get("/people/2.#{format}") {[200, {}, ActiveResource::Middleware::Formats[format].encode(david)]}
          stub.get("/people/2/shallow.#{format}") {[200, {}, ActiveResource::Middleware::Formats[format].encode(david, root: 'person')]} # TODO: SHOULD NOT HAVE TO ADD ROOT!
        end

        remote_programmer = Person.find(2).get(:shallow)['person']
        assert_equal @david[:id], remote_programmer['id']
        assert_equal @david[:name], remote_programmer['name']
      end

      ryan_hash = { :name => 'Ryan' }
      ryan_hash = (format == :json ? { :person => ryan_hash } : ryan_hash)
      ryan = ActiveResource::Middleware::Formats[format].encode(ryan_hash)
      using_format(Person, format) do
        remote_ryan = Person.new(:name => 'Ryan')
        ActiveResource::Stubs.clear
        Person.connection(true)
        ActiveResource::Stubs.add do |stub|
          stub.post("/people.#{format}") {[201, {'Location' => "/people/5.#{format}"}, ryan]}
          stub.post("/people/new/register.#{format}") {[201, {'Location' => "/people/5.#{format}"}, ryan]}
        end
        remote_ryan.save
      
        remote_ryan = Person.new(:name => 'Ryan')
        response = remote_ryan.post(:register)
        assert_equal({'Location' => "/people/5.#{format}"}, response.env[:response_headers])
        assert_equal 201, response.env[:status]
      end
    end
  end

  def test_setting_format_before_site
    resource = Class.new(ActiveResource::Base)
    resource.format = :json
    resource.site   = 'http://37s.sunrise.i:3000'
    assert resource.middleware.handlers.include?(ActiveResource::Middleware::Formats[:json])
  end

  def test_serialization_of_nested_resource
    address  = { :street => '12345 Street' }
    person  = { :name => 'Rus', :address => address}

    [:json, :xml].each do |format|
      encoded_person = ActiveResource::Middleware::Formats[format].encode(person)
      assert_match(/12345 Street/, encoded_person)
      remote_person = Person.new(person.update({:address => StreetAddress.new(address)}))
      assert_kind_of StreetAddress, remote_person.address
      using_format(Person, format) do
        ActiveResource::Stubs.clear
        Person.connection(true)
        ActiveResource::Stubs.add do |stub|
          stub.post("/people.#{format}") {[201, {'Location' => "/people/5.#{format}"}, encoded_person]}
        end
        remote_person.save
      end
    end
  end

  private
    def using_format(klass, mime_type_reference)
      previous_format = klass.format
      klass.format = mime_type_reference

      yield
    ensure
      klass.format = previous_format
    end
end
