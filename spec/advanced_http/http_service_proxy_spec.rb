require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'advanced_http/http_service_proxy'

describe AdvancedHttp::HttpServiceProxy, '.for()' do
  it 'should create a new proxy if an existing one is not found for the URI' do
    Net::HTTP.expects(:new).with('neverbeforeseen.www.example', 80)
    
    AdvancedHttp::HttpServiceProxy.for('http://neverbeforeseen.www.example/foo')
  end 

  it 'should handle URI::HTTP argument' do 
    AdvancedHttp::HttpServiceProxy.for(URI.parse('http://www.example/foo')).
      should be_instance_of(AdvancedHttp::HttpServiceProxy)
  end 

  it 'should handle URI::HTTPS argument' do 
    AdvancedHttp::HttpServiceProxy.for(URI.parse('https://www.example/foo')).
      should be_instance_of(AdvancedHttp::HttpServiceProxy)
  end 
end


describe AdvancedHttp::HttpServiceProxy, '#get() (http)' do

  before do
    @challenge = HTTPAuth::Digest::Challenge.from_header("Digest opaque=\"f9881f17cd67311b1d79abd587675d6e\", nonce=\"MjAwNy0xMC0wMyAwNDoxMjowMDo1NjcyMDk6NTcxMWZmMTEzMGRlMTI1OTNkNjY2NDdmYzFiOTA0Nj\", realm=\"SystemShepherd\", qop=\"auth\", algorithm=MD5-sess")

    @http_req = stub()
    Net::HTTP::Get.stubs(:new).returns(@http_req)
    @http_resp = Net::HTTPOK.new('1.1', '200', 'OK')

    @http_conn = stub('Net::HTTP', :address => 'www.example', :port => 80, :use_ssl? => false, :request => @http_resp)
    Net::HTTP.stubs(:new).returns(@http_conn)

    @proxy = AdvancedHttp::HttpServiceProxy.for('http://www.example/foo')
  end

  it 'should raise AuthenticationRequired if server response is 401 (Unauthorized)' do
    err_resp = Net::HTTPUnauthorized.new('1.1', '401', 'Unauthorized')
    @http_conn.expects(:request).returns(err_resp)
    
    lambda {
      @proxy.get('http://www.example/foo')
    }.should raise_error(AdvancedHttp::AuthenticationRequiredError, 
                         "Authentication is required to access the resource")    
  end 
  
  it 'should raise ClientError if the server response with a 4xx' do
    err_resp = Net::HTTPNotFound.new('1.1', '404', 'Not Found')
    @http_conn.expects(:request).returns(err_resp)
    
    lambda {
      @proxy.get('http://www.example/foo')
    }.should raise_error(AdvancedHttp::ClientError, "There was a problem with the request (Not Found)")
  end

  it 'should raise ServerError if the server response with a 5xx' do
    err_resp = Net::HTTPNotImplemented.new('1.1', '501', 'Not Implemented')
    @http_conn.expects(:request).returns(err_resp)
    
    lambda {
      @proxy.get('http://www.example/foo')
    }.should raise_error(AdvancedHttp::ServerError, "An error occured on the server (Not Implemented)")
  end

  it 'should raise RequestRedirection if the server response with a redirect' do
    redir_resp = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
    redir_resp["location"] = 'http://www.example/new/location'
    @http_conn.expects(:request).returns(redir_resp)
    
    lambda {
      @proxy.get('http://www.example/foo')
    }.should raise_error(AdvancedHttp::RequestRedirected, "Request redirected to 'http://www.example/new/location' (Moved Permanently)")
  end
  
  it 'should raise error on unrecognized options' do 
    lambda { 
      @proxy.get('http://www.example/foo', :bar => 'this')  
    }.should raise_error(ArgumentError, "Unrecognized option(s) bar")
  end


  it 'should set send basic authorization header if account, password, and digest_challenge is not specified' do 
    @http_req.expects(:basic_auth).with('user_a', 'a_resu')

    @proxy.get('http://www.example/foo', :account => 'user_a', :password => 'a_resu')  
  end

  it 'should raise error if account but not password is specified' do 
    lambda { 
      @proxy.get('http://www.example/foo', :account => 'user_a')  
    }.should raise_error(ArgumentError, "The :account and :password options only valid if they are both specified")
  end

  it 'should raise error if password but not account is specified' do 
    lambda { 
      @proxy.get('http://www.example/foo', :password => 'a_resu')  
    }.should raise_error(ArgumentError, "The :account and :password options only valid if they are both specified")
  end

  it 'should set send digest authorization header if account, password, and digest_challenge is specified' do 
    @http_req.expects(:digest_auth).with('user_a', 'a_resu', @challenge)

    @proxy.get('http://www.example/foo', :digest_challenge => @challenge, :account => 'user_a', 
               :password => 'a_resu')  
  end

  it 'should raise error digest_challenge is specified but account is ommited' do 
    lambda {
      @proxy.get('http://www.example/foo', :digest_challenge => @challenge, 
                 :password => 'a_resu')  
    }.should raise_error(ArgumentError, "The :digest_challenge option is only valid if :account and :password options are also specified")
  end

  it 'should raise error digest_challenge is specified but password is ommited' do 
    lambda {
      @proxy.get('http://www.example/foo', :digest_challenge => @challenge, 
                 :account => 'user_a')  
    }.should raise_error(ArgumentError, "The :digest_challenge option is only valid if :account and :password options are also specified")
  end
  
  it 'should set accept header if accept option is specified as string' do 
    @http_req.expects(:delete).with('accept')
    @http_req.expects(:add_field).with("accept", 'application/xhtml+xml')
    
    @proxy.get('http://www.example/foo', :accept => 'application/xhtml+xml')
  end

  it 'should set accept header if accept option is specified as array of strings' do 
    @http_req.expects(:delete).with('accept')
    @http_req.expects(:add_field).with("accept", 'application/xhtml+xml')
    @http_req.expects(:add_field).with("accept", 'application/xml')
    
    @proxy.get('http://www.example/foo', :accept => ['application/xhtml+xml','application/xml'])
  end

  it 'should set accept header if accept option is specified as array of things that responds to #to_str (like ActionController::MimeType)' do 
    @http_req.expects(:delete).with('accept')
    @http_req.expects(:add_field).with("accept", 'application/xhtml+xml')
    @http_req.expects(:add_field).with("accept", 'application/xml')
    
    mt_a = mock(:to_str => 'application/xhtml+xml')
    
    @proxy.get('http://www.example/foo', :accept => [mt_a, 'application/xml'])
  end

  it 'should set accept header if accept option is specified as an object that responds to #to_str (like ActionController::MimeType)' do 
    @http_req.expects(:delete).with('accept')
    @http_req.expects(:add_field).with("accept", 'application/xhtml+xml')
    
    mt_a = mock(:to_str => 'application/xhtml+xml')
    
    @proxy.get('http://www.example/foo', :accept => mt_a)
  end

  it 'should make HTTP request' do
    Net::HTTP::Get.expects(:new).with("/foo").returns(@http_req)
    @http_conn.expects(:request).with(@http_req, nil).returns(@http_resp)
    
    @proxy.get('http://www.example/foo')
  end 
  
  it 'should raise error if URI is not an http(s) uri' do
    lambda {
      @proxy.get('ftp://www.example/foo')
    }.should raise_error(AdvancedHttp::UnsupportedUriSchemeError, "Don't know how to deal with 'ftp' URIs")
  end 
  
  it 'should raise error if URI is a host other than the one proxied by the object' do
    lambda {
      @proxy.get('http://nothere.example/foo')
    }.should raise_error(AdvancedHttp::ServiceUriMismatchError, "This service does not provide the resource indicated by http://nothere.example/foo")
  end

  it 'should raise error for https URIs (even for the same port)' do
    lambda {
      @proxy.get('https://www.example:80/foo')
    }.should raise_error(AdvancedHttp::ServiceUriMismatchError, "This service does not provide the resource indicated by https://www.example:80/foo")
  end
end

describe AdvancedHttp::HttpServiceProxy, '#get() (https)' do
  
  before do
    @http_req = stub()
    @http_resp = Net::HTTPOK.new('1.1', '200', 'OK')

    @http_conn = stub('Net::HTTP', :address => 'www.example', :port => 443, :use_ssl? => true)
    Net::HTTP.stubs(:new).returns(@http_conn)

    @proxy = AdvancedHttp::HttpServiceProxy.for('https://www.example/foo')
  end

  it 'should make HTTPS request' do
    Net::HTTP::Get.expects(:new).with("/foo").returns(@http_req)
    @http_conn.expects(:request).with(@http_req, nil).returns(@http_resp)
    
    @proxy.get('https://www.example/foo')
  end 

  it 'should raise error for http URIs even for the same port' do
    lambda {
      @proxy.get('http://www.example:443/foo')
    }.should raise_error(AdvancedHttp::ServiceUriMismatchError, "This service does not provide the resource indicated by http://www.example:443/foo")
  end

end

# ------

describe AdvancedHttp::HttpServiceProxy, '#post() (http)' do

  before do
    @challenge = HTTPAuth::Digest::Challenge.from_header("Digest opaque=\"f9881f17cd67311b1d79abd587675d6e\", nonce=\"MjAwNy0xMC0wMyAwNDoxMjowMDo1NjcyMDk6NTcxMWZmMTEzMGRlMTI1OTNkNjY2NDdmYzFiOTA0Nj\", realm=\"SystemShepherd\", qop=\"auth\", algorithm=MD5-sess")

    @http_req = stub('http_req')
    @http_req.stubs(:[]=).with('content-type', anything)

    Net::HTTP::Post.stubs(:new).returns(@http_req)
    @http_resp = Net::HTTPOK.new('1.1', '200', 'OK')

    @http_conn = stub('Net::HTTP', :address => 'www.example', :port => 80, :use_ssl? => false, :request => @http_resp)
    Net::HTTP.stubs(:new).returns(@http_conn)

    @proxy = AdvancedHttp::HttpServiceProxy.for('http://www.example/foo')
  end

  it 'should raise AuthenticationRequired if server response is 401 (Unauthorized)' do
    err_resp = Net::HTTPUnauthorized.new('1.1', '401', 'Unauthorized')
    @http_conn.expects(:request).returns(err_resp)
    
    lambda {
      @proxy.post('http://www.example/foo', "this=that", 'application/x-form-urlencoded')
    }.should raise_error(AdvancedHttp::AuthenticationRequiredError, 
                         "Authentication is required to access the resource")    
  end 
  
  it 'should raise ClientError if the server response with a 4xx' do
    err_resp = Net::HTTPNotFound.new('1.1', '404', 'Not Found')
    @http_conn.expects(:request).returns(err_resp)
    
    lambda {
      @proxy.post('http://www.example/foo', "this=that", 'application/x-form-urlencoded')
    }.should raise_error(AdvancedHttp::ClientError, "There was a problem with the request (Not Found)")
  end

  it 'should raise ServerError if the server response with a 5xx' do
    err_resp = Net::HTTPNotImplemented.new('1.1', '501', 'Not Implemented')
    @http_conn.expects(:request).returns(err_resp)
    
    lambda {
      @proxy.post('http://www.example/foo', "this=that", 'application/x-form-urlencoded')
    }.should raise_error(AdvancedHttp::ServerError, "An error occured on the server (Not Implemented)")
  end

  it 'should raise RequestRedirection if the server response with a redirect' do
    redir_resp = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
    redir_resp["location"] = 'http://www.example/new/location'
    @http_conn.expects(:request).returns(redir_resp)
    
    lambda {
      @proxy.post('http://www.example/foo', "this=that", 'application/x-form-urlencoded')
    }.should raise_error(AdvancedHttp::RequestRedirected, "Request redirected to 'http://www.example/new/location' (Moved Permanently)")
  end
  
  it 'should raise error on unrecognized options' do 
    lambda { 
      @proxy.post('http://www.example/foo', "this=that", 'application/x-form-urlencoded', :bar => 'this')  
    }.should raise_error(ArgumentError, "Unrecognized option(s) bar")
  end


  it 'should set send basic authorization header if account, password, and digest_challenge is not specified' do 
    @http_req.expects(:basic_auth).with('user_a', 'a_resu')

    @proxy.post('http://www.example/foo', "this=that", 'application/x-form-urlencoded', :account => 'user_a', :password => 'a_resu')  
  end

  it 'should raise error if account but not password is specified' do 
    lambda { 
      @proxy.post('http://www.example/foo', "this=that", 'application/x-form-urlencoded', :account => 'user_a')  
    }.should raise_error(ArgumentError, "The :account and :password options only valid if they are both specified")
  end

  it 'should raise error if password but not account is specified' do 
    lambda { 
      @proxy.post('http://www.example/foo', "this=that", 'application/x-form-urlencoded', :password => 'a_resu')  
    }.should raise_error(ArgumentError, "The :account and :password options only valid if they are both specified")
  end

  it 'should set send digest authorization header if account, password, and digest_challenge is specified' do 
    @http_req.expects(:digest_auth).with('user_a', 'a_resu', @challenge)

    @proxy.post('http://www.example/foo', "this=that", 'application/x-form-urlencoded', :digest_challenge => @challenge, :account => 'user_a', 
               :password => 'a_resu')  
  end

  it 'should raise error digest_challenge is specified but account is ommited' do 
    lambda {
      @proxy.post('http://www.example/foo', "this=that", 'application/x-form-urlencoded', :digest_challenge => @challenge, 
                 :password => 'a_resu')  
    }.should raise_error(ArgumentError, "The :digest_challenge option is only valid if :account and :password options are also specified")
  end

  it 'should raise error digest_challenge is specified but password is ommited' do 
    lambda {
      @proxy.post('http://www.example/foo', "this=that", 'application/x-form-urlencoded', :digest_challenge => @challenge, 
                 :account => 'user_a')  
    }.should raise_error(ArgumentError, "The :digest_challenge option is only valid if :account and :password options are also specified")
  end
  
  it 'should set accept header if accept option is specified as string' do 
    @http_req.expects(:delete).with('accept')
    @http_req.expects(:add_field).with("accept", 'application/xhtml+xml')
    
    @proxy.post('http://www.example/foo', "this=that", 'application/x-form-urlencoded', :accept => 'application/xhtml+xml')
  end

  it 'should set accept header if accept option is specified as array of strings' do 
    @http_req.expects(:delete).with('accept')
    @http_req.expects(:add_field).with("accept", 'application/xhtml+xml')
    @http_req.expects(:add_field).with("accept", 'application/xml')
    
    @proxy.post('http://www.example/foo', "this=that", 'application/x-form-urlencoded', :accept => ['application/xhtml+xml','application/xml'])
  end

  it 'should set accept header if accept option is specified as array of things that responds to #to_str (like ActionController::MimeType)' do 
    @http_req.expects(:delete).with('accept')
    @http_req.expects(:add_field).with("accept", 'application/xhtml+xml')
    @http_req.expects(:add_field).with("accept", 'application/xml')
    
    mt_a = mock(:to_str => 'application/xhtml+xml')
    
    @proxy.post('http://www.example/foo', "this=that", 'application/x-form-urlencoded', :accept => [mt_a, 'application/xml'])
  end

  it 'should set accept header if accept option is specified as an object that responds to #to_str (like ActionController::MimeType)' do 
    @http_req.expects(:delete).with('accept')
    @http_req.expects(:add_field).with("accept", 'application/xhtml+xml')
    
    mt_a = mock(:to_str => 'application/xhtml+xml')
    
    @proxy.post('http://www.example/foo', "this=that", 'application/x-form-urlencoded', :accept => mt_a)
  end
 
  it 'should set Content-Type header' do
    @http_req.expects(:[]=).with("content-type", 'application/x-form-urlencoded')
    
    @proxy.post('http://www.example/foo', "this=that", 'application/x-form-urlencoded')    
  end 

  it 'should set Content-Type header if mime type is a non-string but it responds to to_str' do
    @http_req.expects(:[]=).with("content-type", 'application/xhtml+xml')
    mt_a = mock(:to_str => 'application/xhtml+xml')
    
    @proxy.post('http://www.example/foo', "this=that", mt_a)    
  end 
  
  it 'should make HTTP request' do
    Net::HTTP::Post.expects(:new).with("/foo").returns(@http_req)
    @http_conn.expects(:request).with(@http_req, "this=that").returns(@http_resp)
    
    @proxy.post('http://www.example/foo', "this=that", 'application/x-form-urlencoded')
  end 
  
  it 'should raise error if URI is not an http(s) uri' do
    lambda {
      @proxy.post('ftp://www.example/foo', "this=that", 'application/x-form-urlencoded')
    }.should raise_error(AdvancedHttp::UnsupportedUriSchemeError, "Don't know how to deal with 'ftp' URIs")
  end 
  
  it 'should raise error if URI is a host other than the one proxied by the object' do
    lambda {
      @proxy.post('http://nothere.example/foo', "this=that", 'application/x-form-urlencoded')
    }.should raise_error(AdvancedHttp::ServiceUriMismatchError, "This service does not provide the resource indicated by http://nothere.example/foo")
  end

  it 'should raise error for https URIs (even for the same port)' do
    lambda {
      @proxy.post('https://www.example:80/foo', "this=that", 'application/x-form-urlencoded')
    }.should raise_error(AdvancedHttp::ServiceUriMismatchError, "This service does not provide the resource indicated by https://www.example:80/foo")
  end
end

describe AdvancedHttp::HttpServiceProxy, '#post() (https)' do
  
  before do
    @http_req = stub('http_req')
    @http_req.stubs(:[]=).with('content-type', anything)
    
    @http_resp = Net::HTTPOK.new('1.1', '200', 'OK')

    @http_conn = stub('Net::HTTP', :address => 'www.example', :port => 443, :use_ssl? => true)
    Net::HTTP.stubs(:new).returns(@http_conn, "this=that", 'application/x-form-urlencoded')

    @proxy = AdvancedHttp::HttpServiceProxy.for('https://www.example/foo')
  end

  it 'should make HTTPS request' do
    Net::HTTP::Post.expects(:new).with("/foo").returns(@http_req)
    @http_conn.expects(:request).with(@http_req, "this=that").returns(@http_resp)
    
    @proxy.post('https://www.example/foo', "this=that", 'application/x-form-urlencoded')
  end 

  it 'should raise error for http URIs even for the same port' do
    lambda {
      @proxy.post('http://www.example:443/foo', "this=that", 'application/x-form-urlencoded')
    }.should raise_error(AdvancedHttp::ServiceUriMismatchError, "This service does not provide the resource indicated by http://www.example:443/foo")
  end

end


