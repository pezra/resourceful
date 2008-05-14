require 'pathname'
require Pathname(__FILE__).dirname + 'spec_helper'

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
end

