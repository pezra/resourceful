
require 'sinatra'
require 'sinatra/test/rspec'

require File.dirname(__FILE__) + '/simple_sinatra_server'

describe "GET /" do
  it 'should render "Hello, world!"' do
    get '/'
    @response.should be_ok
    @response.body.should == "Hello, world!"
  end
end

describe "POST /" do
  it 'should be 201 with no body' do
    post '/'
    @response.should be_ok
    @response.body.should == ""
  end

  it 'should return the request body as the response body' do
    body = "Some text"
    post '/', body
    @response.should be_ok
    @response.body.should == body
  end
end

describe "PUT /" do
  it 'should be 200 with no body' do
    put '/'
    @response.should be_ok
    @response.body.should == ""
  end

  it 'should return the request body as the response body' do
    body = "Some text"
    put '/', body
    @response.should be_ok
    @response.body.should == body
  end
end

describe "DELETE /" do
  it 'should render "Deleted"' do
    delete '/'
    @response.should be_ok
    @response.body.should == "Deleted"
  end
end

describe "/method" do
  it 'should respond with the method used to make the request' do
    %w[get post put delete].each do |verb|
      send verb, '/method'
      @response.body.should == verb.upcase
    end
  end
end

describe "/code/nnn" do
  it 'should respond with the code provided in the url' do
    # Just try a handful
    [100, 200, 201, 301, 302, 304, 403, 404, 500].each do |code|
      get "/code/#{code}"
      @response.status.should == code
    end
  end
end

describe "/header" do
  it 'should set response headers from the query string' do
    get "/header", "X-Foo" => "Bar"
    @response['X-Foo'].should == "Bar"
  end

  it 'should dump the request headers into the body as yaml' do
    get '/header', {}, "X-Foo" => "Bar"
    body = YAML.load(@response.body)
    body['X-Foo'].should == "Bar"
  end
end

describe "/cache" do
  it 'should be normal 200 if the modified query param and the ims header dont match' do
    now = Time.now
    get '/cached', {"modified" => now.httpdate}, {"If-Modified-Since" => (now - 3600).httpdate}
    @response.should be_ok
  end

  it 'should be 304 if the modified query param and the ims header are the same' do
    now = Time.now
    get '/cached', {"modified" => now.httpdate}, {"If-Modified-Since" => now.httpdate}
    @response.status.should == 304
  end
end
