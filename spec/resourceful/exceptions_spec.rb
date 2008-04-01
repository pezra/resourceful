require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'advanced_http/exceptions'

describe AdvancedHttp::HttpRequestError, '.new_from()' do 
  before do
    @request = stub('http-req', :method => 'GET')
    @response = stub('http-resp', :code => '404', :message => 'Not Found')
    @resource = stub('http_resource', :effective_uri => 'http://foo.example/bar')
  end
  
  it 'should create client error when code is 4xx' do
    AdvancedHttp::HttpRequestError.new_from(@request, @response, @resource).should be_instance_of(AdvancedHttp::HttpClientError)
  end 

  it 'should create server error when code is 5xx' do
    @response.stubs(:code).returns('500')

    AdvancedHttp::HttpRequestError.new_from(@request, @response, @resource).should be_instance_of(AdvancedHttp::HttpServerError)
  end 

  it 'should create redirection error when code is 3xx' do
    @response.stubs(:code).returns('300')

    AdvancedHttp::HttpRequestError.new_from(@request, @response, @resource).should be_instance_of(AdvancedHttp::HttpRedirectionError)
  end 

  
  it 'should construct a helpful message for GET failures' do
    AdvancedHttp::HttpRequestError.new_from(@request, @response, @resource).message.should ==
      'http://foo.example/bar Not Found (404)'
  end 

  it 'should construct a helpful message for POST failures' do
    @request.stubs(:method).returns('POST')
    @response.stubs(:message).returns('Hello There')
                   
    AdvancedHttp::HttpRequestError.new_from(@request, @response, @resource).message.should ==
      'Received Hello There response to POST http://foo.example/bar (404)'
  end 

  it 'should construct a helpful message for PUT failures' do
    @request.stubs(:method).returns('PUT')
    @response.stubs(:message).returns('Hello There')
                   
    AdvancedHttp::HttpRequestError.new_from(@request, @response, @resource).message.should ==
      'Received Hello There response to PUT http://foo.example/bar (404)'
  end 
end
