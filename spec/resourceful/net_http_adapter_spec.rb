require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'resourceful/net_http_adapter'

describe Resourceful::NetHttpAdapter do
  it_should_behave_like 'simple http server'

  describe '#make_request' do
    before do
      @response = Resourceful::NetHttpAdapter.make_request(:get, 'http://localhost:3000/get')
    end

    describe 'response' do
      it 'should be an array' do
        @response.should be_instance_of(Array)
      end

      it 'should have the numeric response code as the first element' do
        code = @response[0]
        code.should be_instance_of(Fixnum)
        code.should == 200
      end

      it 'should have the Header as the second element' do
        header = @response[1]
        header.should be_instance_of(Resourceful::Header)
        header['content-type'].should == ['text/plain']
      end

      it 'should have the body as the third and last element' do
        body = @response[2]
        body.should == "Hello, world!"
      end

    end

  end

  describe '#net_http_request_class' do

    it 'should provide Net::HTTP::Get for a get method' do
      Resourceful::NetHttpAdapter.send(:net_http_request_class, :get).should == Net::HTTP::Get
    end

    it 'should provide Net::HTTP::Post for a post method' do
      Resourceful::NetHttpAdapter.send(:net_http_request_class, :post).should == Net::HTTP::Post
    end

    it 'should provide Net::HTTP::Put for a put method' do
      Resourceful::NetHttpAdapter.send(:net_http_request_class, :put).should == Net::HTTP::Put
    end

    it 'should provide Net::HTTP::Delete for a delete method' do
      Resourceful::NetHttpAdapter.send(:net_http_request_class, :delete).should == Net::HTTP::Delete
    end

  end


end

