require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'resourceful/exceptions'

describe Resourceful::HttpRequestError, '.new_from()' do 
  before do
    @request = stub('http-req', :method => 'GET')
    @response = stub('http-resp', :code => '404', :message => 'Not Found')
    @resource = stub('http_resource', :effective_uri => 'http://foo.example/bar')
  end
  
  it 'should create client error when code is 4xx' do
    Resourceful::HttpRequestError.new_from(@request, @response, @resource).should be_instance_of(Resourceful::HttpClientError)
  end 

  it 'should create server error when code is 5xx' do
    @response.stub!(:code).and_return('500')

    Resourceful::HttpRequestError.new_from(@request, @response, @resource).should be_instance_of(Resourceful::HttpServerError)
  end 

  it 'should create redirection error when code is 3xx' do
    @response.stub!(:code).and_return('300')

    Resourceful::HttpRequestError.new_from(@request, @response, @resource).should be_instance_of(Resourceful::HttpRedirectionError)
  end 

  
  it 'should construct a helpful message for GET failures' do
    Resourceful::HttpRequestError.new_from(@request, @response, @resource).message.should ==
      'http://foo.example/bar Not Found (404)'
  end 

  it 'should construct a helpful message for POST failures' do
    @request.stub!(:method).and_return('POST')
    @response.stub!(:message).and_return('Hello There')
                   
    Resourceful::HttpRequestError.new_from(@request, @response, @resource).message.should ==
      'Received Hello There response to POST http://foo.example/bar (404)'
  end 

  it 'should construct a helpful message for PUT failures' do
    @request.stub!(:method).and_return('PUT')
    @response.stub!(:message).and_return('Hello There')
                   
    Resourceful::HttpRequestError.new_from(@request, @response, @resource).message.should ==
      'Received Hello There response to PUT http://foo.example/bar (404)'
  end 
end
