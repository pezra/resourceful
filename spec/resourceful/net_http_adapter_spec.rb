require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'resourceful/net_http_adapter'

describe Resourceful::NetHttpAdapter do
  it_should_behave_like 'simple http server'

  describe '#get' do
    before do
      @response = Resourceful::NetHttpAdapter.get('http://localhost:3000/get')
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

  describe '#post' do
    before do
      @response = Resourceful::NetHttpAdapter.post('http://localhost:3000/post')
    end

  end

end

