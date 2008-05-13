require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'resourceful/response'

describe Resourceful::Response do
  before do
    @net_http = mock('net_http')
    Net::HTTP::Get.stub!(:new).and_return(@net_http)

    @response = Resourceful::Response.new(0, {}, "")
  end

  describe 'init' do

    it 'should be instantiatable' do
      @response.should be_instance_of(Resourceful::Response)
    end

    it 'should take a [code, header, body] array' do
      r = Resourceful::Response.new(200, {}, "")
      r.code.should   == 200
      r.header.should == {}
      r.body.should   == ""
    end

  end

  it 'should have a code' do
    @response.should respond_to(:code)
  end

  it 'should have a header' do
    @response.should respond_to(:header)
  end

  it 'should have header aliased as headers' do
    @response.should respond_to(:headers)
    @response.headers.should == @response.header
  end

  it 'should have a body' do
    @response.should respond_to(:body)
  end

  it 'should know if it is a redirect' do
    Resourceful::Response.new(301, {}, "").is_redirect?.should == true
    Resourceful::Response.new(302, {}, "").is_redirect?.should == true
    Resourceful::Response.new(303, {}, "").is_redirect?.should == true
    Resourceful::Response.new(307, {}, "").is_redirect?.should == true

    #aliased as was_redirect?
    Resourceful::Response.new(301, {}, "").was_redirect?.should == true
  end


end

