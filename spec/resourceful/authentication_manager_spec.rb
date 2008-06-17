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
