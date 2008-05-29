require 'pathname'
require Pathname(__FILE__).dirname + 'spec_helper'
require 'rubygems'
require 'addressable/uri'

require 'resourceful/net_http_adapter'

describe 'http server' do
  it_should_behave_like 'simple http server'

  it 'should have a response code of 200 if the path is /get' do
    Resourceful::NetHttpAdapter.make_request(:get, 'http://localhost:3000/get')[0].should == 200
  end

  it 'should reply with the posted document in the body if the path is /post' do
    resp = Resourceful::NetHttpAdapter.make_request(:get, 'http://localhost:3000/post', 'Hello from POST!')
    resp[2].should == 'Hello from POST!'
    resp[0].should == 201
  end

  it 'should reply with the puted document in the body if the path is /put' do
    resp = Resourceful::NetHttpAdapter.make_request(:put, 'http://localhost:3000/put', 'Hello from PUT!')
    resp[2].should == 'Hello from PUT!'
    resp[0].should == 200
  end

  it 'should reply with "KABOOM!" in the body if the path is /delete' do
    resp = Resourceful::NetHttpAdapter.make_request(:delete, 'http://localhost:3000/delete')
    resp[2].should == 'KABOOM!'
    resp[0].should == 200
  end

  it 'should have a response code of whatever the path is' do
    Resourceful::NetHttpAdapter.make_request(:get, 'http://localhost:3000/code/304')[0].should == 304
  end

  it 'should redirect to a given url' do
    resp = Resourceful::NetHttpAdapter.make_request(:get, 'http://localhost:3000/redirect/301?http://localhost:3000/get')

    resp[0].should == 301
    resp[1]['Location'].should == ['http://localhost:3000/get']
  end

  it 'should respond with the request method in the body' do
    resp = Resourceful::NetHttpAdapter.make_request(:delete, 'http://localhost:3000/method')

    resp[0].should == 200
    resp[2].should == "DELETE"
  end

  it 'should respond with the header set from the query string' do
    uri = URI.escape('http://localhost:3000/header?{Foo: "bar"}')
    resp = Resourceful::NetHttpAdapter.make_request(:get, uri)

    resp[1].should have_key('Foo')
    resp[1]['Foo'].should == ['bar']
  end

  it 'should parse escaped uris properly' do
    uri = URI.escape("http://localhost:3000/header?{Expire: \"#{Time.now.httpdate}\"}")

    resp = Resourceful::NetHttpAdapter.make_request(:get, uri)

    resp[1].should have_key('Expire')
    resp[1]['Expire'].first.should_not =~ /%/
  end

  describe '/modified' do
    it 'should be 200 if no I-M-S header' do
      uri = URI.escape("http://localhost:3000/modified?#{(Time.now + 3600).httpdate}")

      resp = Resourceful::NetHttpAdapter.make_request(:get, uri)

      resp[0].should == 200
    end

    it 'should be 304 if I-M-S header is set' do
      now = Time.utc(2008,5,29,12,00)
      uri = URI.escape("http://localhost:3000/modified?#{(now + 3600).httpdate}")

      resp = Resourceful::NetHttpAdapter.make_request(:get, uri, nil, {'If-Modified-Since' => now.httpdate})

      resp[0].should == 304
    end

  end

  describe '/auth' do

    it 'should be a 401 if no auth header is set' do
      uri = 'http://localhost:3000/auth'
      resp = Resourceful::NetHttpAdapter.make_request(:get, uri)

      resp[0].should == 401
    end

    it 'should be a 200 if any auth header is set' do
      uri = 'http://localhost:3000/auth'
      resp = Resourceful::NetHttpAdapter.make_request(:get, uri, nil, {'Authorization' => 'foobar'})

      resp[0].should == 200
    end
  end




end

