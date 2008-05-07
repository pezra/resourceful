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

  end

  describe 'make' do
    before do
      @net_http = mock('net_http_get')
      Resourceful::NetHttpAdapter.stub!(:get).and_return(@net_http)

      @response = mock('response')
      Resourceful::Response.stub!(:new).and_return(@response)
    end

    it 'should be a method' do
      @request.should respond_to(:make)
    end

    it 'should look in the cache'

    it 'should create a Resourceful::Response object from the Net::HTTP response' do
      Resourceful::Response.should_receive(:new).with(@net_http_response).and_return(@response)
      @request.make
    end

    it 'should return the Response object' do
      @request.make.should == @response
    end

  end

end

