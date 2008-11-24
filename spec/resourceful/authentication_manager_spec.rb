require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'resourceful/authentication_manager'

describe Resourceful::AuthenticationManager do

  before do
    @authmgr = Resourceful::AuthenticationManager.new

    @authenticator = mock('Authenticator')
  end

  [:add_auth_handler, :associate_auth_info, :add_credentials].each do |meth|
    it "should have ##{meth}" do
      @authmgr.should respond_to(meth)
    end
  end

  it 'should add an authenticator to its list' do
    @authmgr.add_auth_handler(@authenticator)
    @authmgr.instance_variable_get("@authenticators").should include(@authenticator)
  end

  describe 'associating authenticators with challanges' do
    before do
      @authmgr.add_auth_handler(@authenticator)
      @authenticator.stub!(:valid_for?).and_return(true)
      @authenticator.stub!(:update_credentials)
      @challenge = mock('Response')
    end

    it 'should check that an authenticator is valid for a challenge' do
      @authenticator.should_receive(:valid_for?).with(@challenge).and_return(true)
      @authmgr.associate_auth_info(@challenge)
    end
   
    it 'should update the credentials of the authenticator if it is valid for the challenge' do
      @authenticator.should_receive(:update_credentials).with(@challenge)
      @authmgr.associate_auth_info(@challenge)
    end

    it 'should not update the credentials of the authenticator if it is not valid for the challenge' do
      @authenticator.stub!(:valid_for?).and_return(false)
      @authenticator.should_not_receive(:update_credentials).with(@challenge)
      @authmgr.associate_auth_info(@challenge)
    end

  end 

  describe 'adding credentials to a request' do
    before do
      @authmgr.add_auth_handler(@authenticator)
      @authenticator.stub!(:can_handle?).and_return(true)
      @authenticator.stub!(:add_credentials_to)
      @request = mock('Request')
    end

    it 'should find an authenticator that can handle the request' do
      @authenticator.should_receive(:can_handle?).with(@request).and_return(true)
      @authmgr.add_credentials(@request)
    end

    it 'should add the authenticators credentials to the request' do
      @authenticator.should_receive(:add_credentials_to).with(@request)
      @authmgr.add_credentials(@request)
    end

    it 'should not add the authenticators credentials to the request if it cant handle it' do
      @authenticator.should_receive(:can_handle?).with(@request).and_return(false)
      @authenticator.should_not_receive(:add_credentials_to).with(@request)
      @authmgr.add_credentials(@request)
    end

  end

end

describe Resourceful::BasicAuthenticator do
  before do 
    @auth = Resourceful::BasicAuthenticator.new('Test Auth', 'admin', 'secret')
  end

  {:realm => 'Test Auth', :username => 'admin', :password => 'secret'}.each do |meth,val|
    it "should initialize with a #{meth}" do
      @auth.instance_variable_get("@#{meth}").should == val
    end
  end

  describe "Updating from a challenge response" do
    before do
      @header = {'WWW-Authenticate' => ['Basic realm="Test Auth"']}
      @chal = mock('response', :header => @header, :uri => 'http://example.com/foo/bar')
    end

    it 'should be valid for a challenge response with scheme "Basic" and the same realm' do
      @auth.valid_for?(@chal).should be_true
    end

    it 'should be valid for a challenge response with multiple schemes including matchin "Basic" challenge' do
      @header = {'WWW-Authenticate' => ['Digest some other stuff', 'Basic realm="Test Auth"', 'Weird scheme']}

      @auth.valid_for?(@chal).should be_true
    end

    it 'should not be sensitive to case variances in the scheme' do
      @header['WWW-Authenticate'] = ['bAsIc realm="Test Auth"']
      @auth.valid_for?(@chal).should be_true
    end

    it 'should not be sensitive to case variances in the realm directive' do
      @header['WWW-Authenticate'] = ['Basic rEaLm="Test Auth"']
      @auth.valid_for?(@chal).should be_true
    end

    it 'should not be sensitive to case variances in the realm value' do
      @header['WWW-Authenticate'] = ['Basic realm="test auth"']
      @auth.valid_for?(@chal).should be_true
    end
 
    it 'should not be valid if the scheme is not "Basic"' do
      @header['WWW-Authenticate'] = ["Digest"]
      @auth.valid_for?(@chal).should be_false
    end

    it 'should not be valid if the realm does not match' do
      @header['WWW-Authenticate'] = ['Basic realm="not test auth"']
      @auth.valid_for?(@chal).should be_false
    end

    it 'should not be valid if the header is unreadable' do
      @header['WWW-Authenticate'] = nil
      @auth.valid_for?(@chal).should be_false
    end

    it 'should set the valid domain from the host part of the challenge uri' do
      @auth.update_credentials(@chal)
      @auth.instance_variable_get("@domain").should == 'example.com'
    end

  end
  
  describe 'updating a request with credentials' do
    before do
      @auth.instance_variable_set("@domain", 'example.com')
      @header = {}
      @req  = mock('request', :uri => 'http://example.com/bar/foo', :header => @header)
    end

    it 'should be able to handle a request for the matching domain' do
      @auth.can_handle?(@req).should be_true
    end

    it 'should add credentials to a request' do
      @header.should_receive(:[]=).with('Authorization', 'Basic YWRtaW46c2VjcmV0')
      @auth.add_credentials_to(@req)
    end

    it 'should build the credentials string for the header' do
      @auth.credentials.should == 'Basic YWRtaW46c2VjcmV0'
    end
  end

end

describe Resourceful::DigestAuthenticator do

  before do 
    @header = {'WWW-Authenticate' => ['Digest realm="Test Auth"']}
    @chal = mock('response', :header => @header, :uri => 'http://example.com/foo/bar')

    @req_header = {}
    @req = mock('request', :header => @req_header, 
                           :uri => 'http://example.com',
                           :method => 'GET')

    @auth = Resourceful::DigestAuthenticator.new('Test Auth', 'admin', 'secret')
  end

  {:realm => 'Test Auth', :username => 'admin', :password => 'secret'}.each do |meth,val|
    it "should initialize with a #{meth}" do
      @auth.instance_variable_get("@#{meth}").should == val
    end
  end

  describe "Updating credentials from a challenge response" do

    it "should set the domain from the host part of the challenge response uri" do
      @auth.update_credentials(@chal)
      @auth.domain.should == 'example.com'
    end

    it "should create an HTTPAuth Digest Challenge from the challenge response WWW-Authenticate header" do
      HTTPAuth::Digest::Challenge.should_receive(:from_header).with(@header['WWW-Authenticate'].first)
      @auth.update_credentials(@chal)
    end

  end

  describe "Validating a challenge" do
    it 'should be valid for a challenge response with scheme "Digest" and the same realm' do
      @auth.valid_for?(@chal).should be_true
    end

    it 'should not be valid if the scheme is not "Digest"' do
      @header['WWW-Authenticate'] = ["Basic"]
      @auth.valid_for?(@chal).should be_false
    end

    it 'should not be valid if the realm does not match' do
      @header['WWW-Authenticate'] = ['Digest realm="not test auth"']
      @auth.valid_for?(@chal).should be_false
    end

    it 'should not be valid if the header is unreadable' do
      @header['WWW-Authenticate'] = nil
      @auth.valid_for?(@chal).should be_false
    end
  end

  it "should be able to handle requests to the same domain" do
    @auth.instance_variable_set("@domain", 'example.com')
    @auth.can_handle?(@req).should be_true
  end

  it "should not handle requests to a different domain" do
    @auth.instance_variable_set("@domain", 'example2.com')
    @auth.can_handle?(@req).should be_false
  end

  it "should add credentials to a request" do
    @auth.update_credentials(@chal)
    @auth.add_credentials_to(@req)
    @req_header.should have_key('Authorization')
    @req_header['Authorization'].should_not be_blank
  end

  it "should have HTTPAuth::Digest generate the Authorization header" do
    @auth.update_credentials(@chal)
    cred = mock('digest_credentials', :to_header => nil)

    HTTPAuth::Digest::Credentials.should_receive(:from_challenge).with(
      @auth.challenge, :username => 'admin', :password => 'secret', :method => 'GET', :uri => ''
    ).and_return(cred)

    cred = @auth.credentials_for(@req)
  end

end
