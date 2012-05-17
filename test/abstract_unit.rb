require File.expand_path('../../load_paths', __FILE__)

lib = File.expand_path("#{File.dirname(__FILE__)}/../lib")
$:.unshift(lib) unless $:.include?('lib') || $:.include?(lib)

require 'minitest/autorun'
require 'active_resource'
require 'active_support'
require 'active_support/test_case'
require 'setter_trap'
require 'active_support/logger'

ActiveResource::Base.logger = ActiveSupport::Logger.new("#{File.dirname(__FILE__)}/debug.log")

def setup_response
  matz_hash = { 'person' => { :id => 1, :name => 'Matz' } }

  @default_request_headers = { 'Content-Type' => 'application/json' }
  @matz  = matz_hash.to_json
  @matz_xml  = matz_hash.to_xml
  @david = { :person => { :id => 2, :name => 'David' } }.to_json
  @greg  = { :person => { :id => 3, :name => 'Greg' } }.to_json
  @addy  = { :address => { :id => 1, :street => '12345 Street', :country => 'Australia' } }.to_json
  @rick  = { :person => { :name => "Rick", :age => 25 } }.to_json
  @joe    = { :person => { :id => 6, :name => 'Joe', :likes_hats => true }}.to_json
  @people = { :people => [ { :person => { :id => 1, :name => 'Matz' } }, { :person => { :id => 2, :name => 'David' } }] }.to_json
  @people_david = { :people => [ { :person => { :id => 2, :name => 'David' } }] }.to_json
  @addresses = { :addresses => [{ :address => { :id => 1, :street => '12345 Street', :country => 'Australia' } }] }.to_json
  @post  = {:id => 1, :title => 'Hello World', :body => 'Lorem Ipsum'}.to_json
  @posts = [{:id => 1, :title => 'Hello World', :body => 'Lorem Ipsum'},{:id => 2, :title => 'Second Post', :body => 'Lorem Ipsum'}].to_json
  @comments = [{:id => 1, :post_id => 1, :content => 'Interesting post'},{:id => 2, :post_id => 1, :content => 'I agree'}].to_json

  # - deep nested resource -
  # - Luis (Customer)
  #   - JK (Customer::Friend)
  #     - Mateo (Customer::Friend::Brother)
  #       - Edith (Customer::Friend::Brother::Child)
  #       - Martha (Customer::Friend::Brother::Child)
  #     - Felipe (Customer::Friend::Brother)
  #       - Bryan (Customer::Friend::Brother::Child)
  #       - Luke (Customer::Friend::Brother::Child)
  #   - Eduardo (Customer::Friend)
  #     - Sebas (Customer::Friend::Brother)
  #       - Andres (Customer::Friend::Brother::Child)
  #       - Jorge (Customer::Friend::Brother::Child)
  #     - Elsa (Customer::Friend::Brother)
  #       - Natacha (Customer::Friend::Brother::Child)
  #     - Milena (Customer::Friend::Brother)
  #
  @luis = {
    :customer => {
      :id => 1,
      :name => 'Luis',
      :friends => [{
        :name => 'JK',
        :brothers => [
          {
            :name => 'Mateo',
            :children => [{ :name => 'Edith' },{ :name => 'Martha' }]
          }, {
            :name => 'Felipe',
            :children => [{ :name => 'Bryan' },{ :name => 'Luke' }]
          }
        ]
      }, {
        :name => 'Eduardo',
        :brothers => [
          {
            :name => 'Sebas',
            :children => [{ :name => 'Andres' },{ :name => 'Jorge' }]
          }, {
            :name => 'Elsa',
            :children => [{ :name => 'Natacha' }]
          }, {
            :name => 'Milena',
            :children => []
          }
        ]
      }],
      :enemies => [{:name => 'Joker'}],
      :mother => {:name => 'Ingeborg'}
    }
  }.to_json
  # - resource with yaml array of strings; for ARs using serialize :bar, Array
  @marty = <<-eof.strip
    <?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <person>
      <id type=\"integer\">5</id>
      <name>Marty</name>
      <colors type=\"yaml\">---
    - \"red\"
    - \"green\"
    - \"blue\"
    </colors>
    </person>
  eof

  @startup_sound = {
    :sound => {
      :name => "Mac Startup Sound", :author => { :name => "Jim Reekes" }
    }
  }.to_json
  
  @product = {id: 1, name: 'Rails book'}.to_json
  @inventory = {status: 'Sold Out', total: 10, used: 10}.to_json

  ActiveResource::Stubs.set do |stub|
    stub.get("/people/1.json")                {[200, {}, @matz]}
    stub.get("/people/1.xml")                 {[200, {}, @matz_xml]}
    stub.get("/people/2.xml")                 {[200, {}, @david ]} 
    stub.get("/people/5.xml")                 {[200, {}, @marty ]} 
    stub.get("/people/Greg.json")             {[200, {}, @greg]}
    stub.get("/people/6.json")                {[200, {}, @joe]}
    stub.get("/people/4.json")                {[404, {'key' => 'value'}, nil]}
    stub.put("/people/1.json")                {[204, {}, nil]}
    stub.delete("/people/1.json")             {[200, {}, nil]}
    stub.delete("/people/2.xml")              {[400, {}, nil]}
    stub.get("/people/99.json")               {[404, {}, nil]}
    stub.post("/people.json")                 {[201, {'Location' => '/people/5.xml'}, @rick]}
    stub.get("/people.json")                  {[200, {}, @people]}
    stub.get("/people/1/addresses.json")      {[200, {}, @addresses]}
    stub.get("/people/1/addresses/1.json")    {[200, {}, @addy]}
    stub.get("/people/1/addresses/2.xml")     {[404, {}, nil]}
    stub.get("/people/2/addresses.json")      {[404, {}, nil]}
    stub.get("/people/2/addresses/1.xml")     {[404, {}, nil]}
    stub.get("/people/Greg/addresses/1.json") {[200, {}, @addy]}
    stub.put("/people/1/addresses/1.json")    {[204, {}, nil]}
    stub.delete("/people/1/addresses/1.json") {[200, {}, nil]}
    stub.post("/people/1/addresses.json")     {[200, {'Location' => '/people/1/addresses/5'}, nil]}
    stub.get("/people/1/addresses/99.json")   {[404, {}, nil]}
    stub.get("/people//addresses.xml")        {[404, {}, nil]}
    stub.get("/people//addresses/1.xml")      {[404, {}, nil]}
    stub.put("/people//addresses/1.xml")      {[404, {}, nil]}
    stub.delete("/people//addresses/1.xml")   {[404, {}, nil]}
    stub.post("/people//addresses.xml")       {[404, {}, nil]}
    stub.head("/people/1.json")               {[200, {}, nil]}
    stub.head("/people/Greg.json")            {[200, {}, nil]}
    stub.head("/people/99.json")              {[404, {}, nil]}
    stub.head("/people/1/addresses/1.json")   {[200, {}, nil]}
    stub.head("/people/1/addresses/2.json")   {[404, {}, nil]}
    stub.head("/people/2/addresses/1.json")   {[404, {}, nil]}
    stub.head("/people/Greg/addresses/1.json"){[200, {}, nil]}
    stub.get('/companies/1/people.json')      {[200, {}, @people_david]}
    # customer
    stub.get("/customers/1.json")             {[200, {}, @luis]}
    # sound
    stub.get("/sounds/1.json")                {[200, {}, @startup_sound]}
    # post
    stub.get("/posts.json")                   {[200, {}, @posts]}
    stub.get("/posts/1.json")                 {[200, {}, @post]}
    stub.get("/posts/1/comments.json")        {[200, {}, @comments]}
    # products
    stub.get('/products/1.json')              {[200, {}, @product]}
    stub.get('/products/1/inventory.json')    {[200, {}, @inventory]}
  end


  Person.user = nil
  Person.password = nil
end
