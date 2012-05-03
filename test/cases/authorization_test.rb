require 'abstract_unit'

class AuthorizationTest < ActiveSupport::TestCase
  Response = Struct.new(:code)

  def setup
    @conn = Faraday.new('http://localhost')
    @matz  = { :person => { :id => 1, :name => 'Matz' } }.to_json
    @david = { :person => { :id => 2, :name => 'David' } }.to_json
    @authenticated_conn = Faraday.new("http://david:test123@localhost")
    @basic_authorization_request_header = { 'Authorization' => 'Basic ZGF2aWQ6dGVzdDEyMw==' }
  end

  private
    def decode(response)
      @authenticated_conn.format.decode(response.body)
    end
end

class BasicAuthorizationTest < AuthorizationTest
  def setup
    super
    @authenticated_conn.auth_type = :basic

    ActiveResource::Base.set_adapter(:test) do |stub|
      stub.get("/people/2.json")              {|env| env[:request_headers] = @basic_authorization_request_header; [200, {}, @david]}
      stub.get("/people/1.json")              {|env| env[:request_headers] = @basic_authorization_request_header; [401, {'WWW-Authenticate' => 'i_should_be_ignored'}, '']}
      stub.put("/people/2.json")              {|env| env[:request_headers] = @basic_authorization_request_header; [204, {}, '']}
      stub.delete("/people/2.json")           {|env| env[:request_headers] = @basic_authorization_request_header; [200, {}, '']}
      stub.post("/people/2/addresses.json")   {|env| env[:request_headers] = @basic_authorization_request_header; [201, {'Location' => '/people/1/addresses/5'}, '']}
      stub.head("/people/2.json")             {|env| env[:request_headers] = @basic_authorization_request_header; [200, {}, '']}
    end
  end

  def test_get
    david = decode(@authenticated_conn.get("/people/2.json"))
    assert_equal "David", david["name"]
  end

  def test_post
    response = @authenticated_conn.post("/people/2/addresses.json")
    assert_equal "/people/1/addresses/5", response["Location"]
  end

  def test_put
    response = @authenticated_conn.put("/people/2.json")
    assert_equal 204, response.code
  end

  def test_delete
    response = @authenticated_conn.delete("/people/2.json")
    assert_equal 200, response.code
  end

  def test_head
    response = @authenticated_conn.head("/people/2.json")
    assert_equal 200, response.code
  end

  def test_retry_on_401_doesnt_happen_with_basic_auth
    assert_raise(ActiveResource::UnauthorizedAccess) { @authenticated_conn.get("/people/1.json") }
    assert_equal "", @authenticated_conn.send(:response_auth_header)
  end

  def test_raises_invalid_request_on_unauthorized_requests
    assert_raise(ActiveResource::InvalidRequestError) { @conn.get("/people/2.json") }
    assert_raise(ActiveResource::InvalidRequestError) { @conn.post("/people/2/addresses.json") }
    assert_raise(ActiveResource::InvalidRequestError) { @conn.put("/people/2.json") }
    assert_raise(ActiveResource::InvalidRequestError) { @conn.delete("/people/2.json") }
    assert_raise(ActiveResource::InvalidRequestError) { @conn.head("/people/2.json") }
  end


  def test_authorization_header
    authorization_header = @authenticated_conn.__send__(:authorization_header, :get, URI.parse('/people/2.json'))
    assert_equal @basic_authorization_request_header['Authorization'], authorization_header['Authorization']
    authorization = authorization_header["Authorization"].to_s.split

    assert_equal "Basic", authorization[0]
    assert_equal ["david", "test123"], ::Base64.decode64(authorization[1]).split(":")[0..1]
  end

  def test_authorization_header_with_username_but_no_password
    @conn = ActiveResource::Connection.new("http://david:@localhost")
    authorization_header = @conn.__send__(:authorization_header, :get, URI.parse('/people/2.json'))
    authorization = authorization_header["Authorization"].to_s.split

    assert_equal "Basic", authorization[0]
    assert_equal ["david"], ::Base64.decode64(authorization[1]).split(":")[0..1]
  end

  def test_authorization_header_with_password_but_no_username
    @conn = ActiveResource::Connection.new("http://:test123@localhost")
    authorization_header = @conn.__send__(:authorization_header, :get, URI.parse('/people/2.json'))
    authorization = authorization_header["Authorization"].to_s.split

    assert_equal "Basic", authorization[0]
    assert_equal ["", "test123"], ::Base64.decode64(authorization[1]).split(":")[0..1]
  end

  def test_authorization_header_with_decoded_credentials_from_url
    @conn = ActiveResource::Connection.new("http://my%40email.com:%31%32%33@localhost")
    authorization_header = @conn.__send__(:authorization_header, :get, URI.parse('/people/2.json'))
    authorization = authorization_header["Authorization"].to_s.split

    assert_equal "Basic", authorization[0]
    assert_equal ["my@email.com", "123"], ::Base64.decode64(authorization[1]).split(":")[0..1]
  end

  def test_authorization_header_explicitly_setting_username_and_password
    @authenticated_conn = ActiveResource::Connection.new("http://@localhost")
    @authenticated_conn.user = 'david'
    @authenticated_conn.password = 'test123'
    authorization_header = @authenticated_conn.__send__(:authorization_header, :get, URI.parse('/people/2.json'))
    assert_equal @basic_authorization_request_header['Authorization'], authorization_header['Authorization']
    authorization = authorization_header["Authorization"].to_s.split

    assert_equal "Basic", authorization[0]
    assert_equal ["david", "test123"], ::Base64.decode64(authorization[1]).split(":")[0..1]
  end

  def test_authorization_header_explicitly_setting_username_but_no_password
    @conn = ActiveResource::Connection.new("http://@localhost")
    @conn.user = "david"
    authorization_header = @conn.__send__(:authorization_header, :get, URI.parse('/people/2.json'))
    authorization = authorization_header["Authorization"].to_s.split

    assert_equal "Basic", authorization[0]
    assert_equal ["david"], ::Base64.decode64(authorization[1]).split(":")[0..1]
  end

  def test_authorization_header_explicitly_setting_password_but_no_username
    @conn = ActiveResource::Connection.new("http://@localhost")
    @conn.password = "test123"
    authorization_header = @conn.__send__(:authorization_header, :get, URI.parse('/people/2.json'))
    authorization = authorization_header["Authorization"].to_s.split

    assert_equal "Basic", authorization[0]
    assert_equal ["", "test123"], ::Base64.decode64(authorization[1]).split(":")[0..1]
  end

  def test_authorization_header_if_credentials_supplied_and_auth_type_is_basic
    authorization_header = @authenticated_conn.__send__(:authorization_header, :get, URI.parse('/people/2.json'))
    assert_equal @basic_authorization_request_header['Authorization'], authorization_header['Authorization']
    authorization = authorization_header["Authorization"].to_s.split

    assert_equal "Basic", authorization[0]
    assert_equal ["david", "test123"], ::Base64.decode64(authorization[1]).split(":")[0..1]
  end

  def test_client_nonce_is_not_nil
    assert_not_nil ActiveResource::Connection.new("http://david:test123@localhost").send(:client_nonce)
  end
end

class DigestAuthorizationTest < AuthorizationTest
  def setup
    super
    @authenticated_conn.auth_type = :digest

    # Make client nonce deterministic
    def @authenticated_conn.client_nonce; 'i-am-a-client-nonce' end

    @nonce = "MTI0OTUxMzc4NzpjYWI3NDM3NDNmY2JmODU4ZjQ2ZjcwNGZkMTJiMjE0NA=="

    ActiveResource::Base.set_adapter(:test) do |stub|
      stub.get("/people/2.json") { |env| env[:request_headers]['Authorization'] = blank_digest_auth_header("/people/2.json", "fad396f6a34aeba28e28b9b96ddbb671"); [401, {'WWW-Authenticate' => response_digest_auth_header}, '']}
      stub.get("/people/2.json") { |env| env[:request_headers]['Authorization'] = request_digest_auth_header("/people/2.json", "c064d5ba8891a25290c76c8c7d31fb7b"); [200, {}, @david]}
      stub.get("/people/1.json") { |env| env[:request_headers]['Authorization'] = request_digest_auth_header("/people/1.json", "f9c0b594257bb8422af4abd429c5bb70"); [200, {}, @matz]}

      stub.put("/people/2.json") { |env| env[:request_headers]['Authorization'] = blank_digest_auth_header("/people/2.json", "50a685d814f94665b9d160fbbaa3958a"); [401, {'WWW-Authenticate' => response_digest_auth_header}, '']}
      stub.put("/people/2.json") { |env| env[:request_headers]['Authorization'] = request_digest_auth_header("/people/2.json", "5a75cde841122d8e0f20f8fd1f98a743"); [204, {}, '']}

      stub.delete("/people/2.json") { |env| env[:request_headers]['Authorization'] = blank_digest_auth_header("/people/2.json", "846f799107eab5ca4285b909ee299a33"); [401, {'WWW-Authenticate'=>response_digest_auth_header}, '']}
      stub.delete("/people/2.json") { |env| env[:request_headers]['Authorization'] = request_digest_auth_header("/people/2.json", "9f5b155224edbbb69fd99d8ce094681e"); [200, {}, '']}

      stub.post("/people/2/addresses.json") { |env| env[:request_headers]['Authorization'] = blank_digest_auth_header("/people/2/addresses.json", "6984d405ff3d9ed07bbf747dcf16afb0"); [401, {'WWW-Authenticate'=>response_digest_auth_header}, '']}
      stub.post("/people/2/addresses.json") { |env| env[:request_headers]['Authorization'] = request_digest_auth_header("/people/2/addresses.json", "4bda6a28dbf930b5af9244073623bd04"); [201, {'Location' => '/people/1/addresses/5'}, '']}

      stub.head("/people/2.json") { |env| env[:request_headers]['Authorization'] = blank_digest_auth_header("/people/2.json", "15e5ed84ba5c4cfcd5c98a36c2e4f421"); [401, {'WWW-Authenticate'=>response_digest_auth_header}, '']}
      stub.head("/people/2.json") { |env| env[:request_headers]['Authorization'] = request_digest_auth_header("/people/2.json", "d4c6d2bcc8717abb2e2ccb8c49ee6a91"); [200, {}, '']}
    end
  end

  def test_authorization_header_if_credentials_supplied_and_auth_type_is_digest
    authorization_header = @authenticated_conn.__send__(:authorization_header, :get, URI.parse('/people/2.json'))
    assert_equal blank_digest_auth_header("/people/2.json", "fad396f6a34aeba28e28b9b96ddbb671"), authorization_header['Authorization']
  end

  def test_authorization_header_with_query_string_if_auth_type_is_digest
    authorization_header = @authenticated_conn.__send__(:authorization_header, :get, URI.parse('/people/2.json?only=name'))
    assert_equal blank_digest_auth_header("/people/2.json?only=name", "f8457b0b5d21b6b80737a386217afb24"), authorization_header['Authorization']
  end

  def test_get_with_digest_auth_handles_initial_401_response_and_retries
    response = @authenticated_conn.get("/people/2.json")
    assert_equal "David", decode(response)["name"]
  end

  def test_post_with_digest_auth_handles_initial_401_response_and_retries
    response = @authenticated_conn.post("/people/2/addresses.json")
    assert_equal "/people/1/addresses/5", response["Location"]
    assert_equal 201, response.code
  end

  def test_put_with_digest_auth_handles_initial_401_response_and_retries
    response = @authenticated_conn.put("/people/2.json")
    assert_equal 204, response.code
  end

  def test_delete_with_digest_auth_handles_initial_401_response_and_retries
    response = @authenticated_conn.delete("/people/2.json")
    assert_equal 200, response.code
  end

  def test_head_with_digest_auth_handles_initial_401_response_and_retries
    response = @authenticated_conn.head("/people/2.json")
    assert_equal 200, response.code
  end

  def test_get_with_digest_auth_caches_nonce
    response = @authenticated_conn.get("/people/2.json")
    assert_equal "David", decode(response)["name"]

    # There is no mock for this request with a non-cached nonce.
    response = @authenticated_conn.get("/people/1.json")
    assert_equal "Matz", decode(response)["name"]
  end

  def test_raises_invalid_request_on_unauthorized_requests_with_digest_auth
    @conn.auth_type = :digest
    assert_raise(ActiveResource::InvalidRequestError) { @conn.get("/people/2.json") }
    assert_raise(ActiveResource::InvalidRequestError) { @conn.post("/people/2/addresses.json") }
    assert_raise(ActiveResource::InvalidRequestError) { @conn.put("/people/2.json") }
    assert_raise(ActiveResource::InvalidRequestError) { @conn.delete("/people/2.json") }
    assert_raise(ActiveResource::InvalidRequestError) { @conn.head("/people/2.json") }
  end

  private
    def blank_digest_auth_header(uri, response)
      %Q(Digest username="david", realm="", qop="", uri="#{uri}", nonce="", nc="0", cnonce="i-am-a-client-nonce", opaque="", response="#{response}")
    end

    def request_digest_auth_header(uri, response)
      %Q(Digest username="david", realm="RailsTestApp", qop="auth", uri="#{uri}", nonce="#{@nonce}", nc="0", cnonce="i-am-a-client-nonce", opaque="ef6dfb078ba22298d366f99567814ffb", response="#{response}")
    end

    def response_digest_auth_header
      %Q(Digest realm="RailsTestApp", qop="auth", algorithm=MD5, nonce="#{@nonce}", opaque="ef6dfb078ba22298d366f99567814ffb")
    end
end
