require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'resourceful/resource'

describe Resourceful::Resource do
  before do
    @accessor = mock('http_accessor')
    @uri      = 'http://www.example.com/'
    @resource = Resourceful::Resource.new(@accessor, @uri)

    @response = mock('response')

    @request = mock('request', :make => @response)
    Resourceful::Request.stub!(:new).and_return(@request)
  end

  describe 'init' do
    it 'should be instantiatable' do
      @resource.should be_instance_of(Resourceful::Resource)
    end

    it 'should take an http_accessor' do
      @resource.accessor.should == @accessor
    end

    it 'should take a uri' do
      @resource.uri.should == @uri
    end

  end

  describe '#get' do

    it 'should be a method' do
      @resource.should respond_to(:get)
    end

    it 'should create a request object with GET method and itself' do
      Resourceful::Request.should_receive(:new).with(:get, @resource).and_return(@request)
      @resource.get
    end

    it 'should make the request' do
      @request.should_receive(:make)
      @resource.get
    end

    it 'should return the response of making the request' do
      @resource.get.should == @request.make
    end

  end

end

