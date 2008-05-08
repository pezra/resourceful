require 'pathname'
require Pathname(__FILE__).dirname + 'spec_helper'

require 'resourceful'

describe Resourceful do
  it_should_behave_like 'simple http server'

  describe 'getting a resource' do
    before do
      @accessor = Resourceful::HttpAccessor.new
    end

    it 'should #get a resource, and return a response object' do
      resource = @accessor.resource('http://localhost:3000/get')
      resp = resource.get
      resp.should be_instance_of(Resourceful::Response)
      resp.code.should == 200
      resp.body.should == 'Hello, world!'
      resp.header.should be_instance_of(Resourceful::Header)
      resp.header['Content-Type'].should == ['text/plain']
    end

    it 'should #post a resource, and return the response' do
      resource = @accessor.resource('http://localhost:3000/post')
      resp = @resource.post('Hello, world from POST')
      resp.should be_instance_of(Resourceful::Response)
    end

    it 'should explode when response code is invalid'

  end

end
