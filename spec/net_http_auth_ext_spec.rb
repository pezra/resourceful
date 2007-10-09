require 'pathname'
require Pathname(__FILE__).dirname + 'spec_helper'

require 'net_http_auth_ext'

describe Net::HTTPUnauthorized do
  DIGEST_CHALLANGE = "Digest opaque=\"f9881f17cd67311b1d79abd587675d6e\", nonce=\"MjAwNy0xMC0wMyAwNDoxMjowMDo1NjcyMDk6NTcxMWZmMTEzMGRlMTI1OTNkNjY2NDdmYzFiOTA0Nj\", realm=\"SystemShepherd\", qop=\"auth\", algorithm=MD5-sess"
  BASIC_CHALLANGE = "Basic realm=\"SystemShepherd\""

  before do
    @resp = Net::HTTPUnauthorized.new('1.1', '401', 'Unauthorized') 
  end
  
  it 'should know when a digest challenge is included' do
    @resp.add_field('WWW-Authenticate', DIGEST_CHALLANGE)
    @resp.digest_auth_allowed?.should == true
  end 

  it 'should know when a digest challenge is included even if the case of the auth-scheme token is cased abnormally' do 
    @resp.add_field('WWW-Authenticate', DIGEST_CHALLANGE.gsub('Digest', 'dIgEsT'))
    @resp.digest_auth_allowed?.should == true
  end 

  it 'should know when a digest challenge is not included' do
    @resp.add_field('WWW-Authenticate', BASIC_CHALLANGE)
    @resp.digest_auth_allowed?.should == false
  end 
  
  it 'should know a digest challenge is included when both a digest and basic challenge are included' do
    @resp.add_field('WWW-Authenticate', BASIC_CHALLANGE)
    @resp.add_field('WWW-Authenticate', DIGEST_CHALLANGE)
    @resp.add_field('WWW-Authenticate', BASIC_CHALLANGE)
    @resp.digest_auth_allowed?.should == true 
  end 

  it 'should know when a basic challenge is included' do
    @resp.add_field('WWW-Authenticate', BASIC_CHALLANGE)
    @resp.basic_auth_allowed?.should == true
  end 

  it 'should know when a basic challenge is included even if the case of the auth-scheme token is cased abnormally' do 
    @resp.add_field('WWW-Authenticate', BASIC_CHALLANGE.gsub('Basic', 'bAsIc'))
    @resp.basic_auth_allowed?.should == true
  end 

  it 'should know when a basic challenge is not included' do
    @resp.add_field('WWW-Authenticate', DIGEST_CHALLANGE)
    @resp.basic_auth_allowed?.should == false
  end 

  it 'should know a basic challenge was included when both a digest and basic challenge are included' do
    @resp.add_field('WWW-Authenticate', DIGEST_CHALLANGE)
    @resp.add_field('WWW-Authenticate', BASIC_CHALLANGE)
    @resp.add_field('WWW-Authenticate', DIGEST_CHALLANGE)
    @resp.basic_auth_allowed?.should == true 
  end 
  
  it 'should be able to extract the digest challenge' do
    @resp.add_field('WWW-Authenticate', DIGEST_CHALLANGE)
    @resp.digest_challenge.should be_instance_of(HTTPAuth::Digest::Challenge)
    @resp.digest_challenge.qop.should == ['auth']
    @resp.digest_challenge.algorithm.should == 'MD5-sess'
    @resp.digest_challenge.realm.should == 'SystemShepherd'
  end 

  it 'should handle the absence of a digest challenge gracefully' do
    @resp.add_field('WWW-Authenticate', BASIC_CHALLANGE)
    @resp.digest_challenge.should be_nil
  end  
end 

describe Net::HTTPRequest do
  DIGEST_CHALLANGE = "Digest opaque=\"f9881f17cd67311b1d79abd587675d6e\", nonce=\"MjAwNy0xMC0wMyAwNDoxMjowMDo1NjcyMDk6NTcxMWZmMTEzMGRlMTI1OTNkNjY2NDdmYzFiOTA0Nj\", realm=\"SystemShepherd\", qop=\"auth\", algorithm=MD5-sess"
  
  before do
    @challenge = HTTPAuth::Digest::Challenge.from_header(DIGEST_CHALLANGE)
  end
  
  it 'should know it is an authenticating request if digest_auth has been called' do 
    req = Net::HTTP::Get.new('/foo')
    req.digest_auth('me', 'mine', @challenge)
    
    req.authenticating?.should == true
  end 

  it 'should know it is an authenticating request if basic_auth has been called' do 
    req = Net::HTTP::Get.new('/foo')
    req.basic_auth('me', 'mine')
    
    req.authenticating?.should == true
  end 

  it 'should know it is not an authenticating request if neither digest_auth nor basic_auth has been called' do 
    req = Net::HTTP::Get.new('/foo')
    
    req.authenticating?.should == false
  end 
  
  it 'should be able to populate authorization header from digest_auth information' do
    req = Net::HTTP::Get.new('/foo')
    req.digest_auth('me', 'mine', @challenge)

    req['Authorization'].should_not be_nil
    req['Authorization'].should =~ /realm="SystemShepherd"/
    req['Authorization'].should =~ %r|uri="/foo"|
    req['Authorization'].should =~ /username="me"/
  end

  it 'should be able to populate authorization header from digest_auth information for HTTPS connections' do
    req = Net::HTTP::Get.new('/foo')
    req.digest_auth('me', 'mine', @challenge)

    req['Authorization'].should_not be_nil
    req['Authorization'].should =~ /realm="SystemShepherd"/
    req['Authorization'].should =~ %r|uri="/foo"|
    req['Authorization'].should =~ /username="me"/
  end

  it 'should be able to populate authorization header from digest_auth information for connections on non-default ports' do
    req = Net::HTTP::Get.new('/foo')
    req.digest_auth('me', 'mine', @challenge)

    req['Authorization'].should_not be_nil
    req['Authorization'].should =~ /realm="SystemShepherd"/
    req['Authorization'].should =~ %r|uri="/foo"|
    req['Authorization'].should =~ /username="me"/
  end

  it 'should be able to populate authorization header from digest_auth information to uri with query string' do
    req = Net::HTTP::Get.new('/foo?this=that')
    req.digest_auth('me', 'mine', @challenge)

    req['Authorization'].should_not be_nil
    req['Authorization'].should =~ /realm="SystemShepherd"/
    req['Authorization'].should =~ %r|uri="/foo\?this\=that"|
    req['Authorization'].should =~ /username="me"/
  end

  it 'should not populate authorization header id not digest information was provided' do
    req = Net::HTTP::Get.new('/foo?this=that')

    req['Authorization'].should be_nil
  end
end 

describe Net::HTTP do
  it 'should cause authorization header to calculated' do
    req = mock('request',
               :set_body_internal => nil, :path => '/foo', :exec => nil, :response_body_permitted? => true)
    resp = mock('response', :reading_body => nil)
    
    http = Net::HTTP.new('example.com', 80)
    http.expects(:start)
    http.expects(:begin_transport).with(req)
    http.expects(:end_transport).with(req, resp)

    Net::HTTPResponse.expects(:read_new).with(nil).returns(resp)
    
    http.request(req)
  end 
end 

