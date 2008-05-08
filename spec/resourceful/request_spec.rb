require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'
require 'rubygems'
require 'addressable/uri'

require 'resourceful/request'

describe Resourceful::Request do
  before do
    @uri = Addressable::URI.parse('http://www.example.com')
    @resource = mock('resource')
    @resource.stub!(:uri).and_return(@uri)

    @request = Resourceful::Request.new(:get, @resource)
  end

  describe 'init' do

    it 'should be instantiatable' do
      @request.should be_instance_of(Resourceful::Request)
    end

    it 'should take an http method' do
      @request.method.should == :get
    end

    it 'should take a resource' do
      @request.resource.should == @resource
    end

    it 'should take an optional body' do
      req = Resourceful::Request.new(:get, @resource)
      req.body.should be_nil

      req = Resourceful::Request.new(:post, @resource, 'Hello from post!')
      req.body.should == 'Hello from post!'
    end

  end

  describe 'make' do
    before do
      @net_http_adapter_response = mock('net_http_adapter_response')
      Resourceful::NetHttpAdapter.stub!(:make_request).and_return(@net_http_adapter_response)

      @response = mock('response')
      Resourceful::Response.stub!(:new).and_return(@response)
    end

    it 'should be a method' do
      @request.should respond_to(:make)
    end

    it 'should look in the cache'

    it 'should create a Resourceful::Response object from the NetHttpAdapter response' do
      Resourceful::Response.should_receive(:new).with(@net_http_adapter_response).and_return(@response)
      @request.make
    end

    it 'should return the Response object' do
      @request.make.should == @response
    end

    describe 'GET' do
      before do
        @request = Resourceful::Request.new(:get, @resource)
      end

      it 'should #get the uri from the NetHttpAdapter' do
        Resourceful::NetHttpAdapter.should_receive(:make_request).
          with(:get, @uri, nil, nil).and_return(@net_http_adapter_response)
        @request.make
      end

    end

    describe 'POST' do
      before do
        @post_data = 'Hello from post!'
        @request = Resourceful::Request.new(:post, @resource, @post_data)
      end

      it 'should #get the uri from the NetHttpAdapter' do
        Resourceful::NetHttpAdapter.should_receive(:make_request).with(:post, @uri, @post_data, nil).and_return(@net_http_adapter_response)
        @request.make
      end


    end

  end

end

