require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'resourceful/response'

describe Resourceful::Response do
  before do
    @net_http = mock('net_http')
    Net::HTTP::Get.stub!(:new).and_return(@net_http)

    @response = Resourceful::Response.new(0, {}, "")
  end

  describe 'init' do

    it 'should be instantiatable' do
      @response.should be_instance_of(Resourceful::Response)
    end

    it 'should take a [code, header, body] array' do
      r = Resourceful::Response.new(200, {}, "")
      r.code.should   == 200
      r.header.should == {}
      r.body.should   == ""
    end

  end

  it 'should have a code' do
    @response.should respond_to(:code)
  end

  it 'should have a header' do
    @response.should respond_to(:header)
  end

  it 'should have header aliased as headers' do
    @response.should respond_to(:headers)
    @response.headers.should == @response.header
  end

  it 'should have a body' do
    @response.should respond_to(:body)
  end

  it 'should know if it is a redirect' do
    Resourceful::Response.new(301, {}, "").is_redirect?.should == true
    Resourceful::Response.new(302, {}, "").is_redirect?.should == true
    Resourceful::Response.new(303, {}, "").is_redirect?.should == true
    Resourceful::Response.new(307, {}, "").is_redirect?.should == true

    #aliased as was_redirect?
    Resourceful::Response.new(301, {}, "").was_redirect?.should == true
  end

  it 'should know if it is a permanent redirect' do
    Resourceful::Response.new(301, {}, "").is_permanent_redirect?.should == true
  end

  it 'should know if it is a temporary redirect' do
    Resourceful::Response.new(303, {}, "").is_temporary_redirect?.should == true
  end

  it 'should know if its authoritative' do
    @response.should respond_to(:authoritative?)
  end

  it 'should allow authoritative to be set' do
    @response.authoritative = true
    @response.authoritative?.should be_true
  end

  describe 'caching and expiration' do
    before do
      Time.stub!(:now).and_return(Time.utc(2008,5,15,18,0,1), Time.utc(2008,5,15,20,0,0))

      @response = Resourceful::Response.new(0, {'Date' => ['Thu, 15 May 2008 18:00:00 GMT']}, "")
      @response.request_time = Time.utc(2008,5,15,17,59,59)
    end

    it 'should know if its #stale?' do
      @response.should respond_to(:stale?)
    end

    it 'should be stale if it is expired' do
      @response.should_receive(:expired?).and_return(true)
      @response.should be_stale
    end

    it 'should know if its #expired?' do
      @response.should respond_to(:expired?)
    end

    it 'should be expired if Now is after the "Expire" header' do
      Time.stub!(:now).and_return(Time.utc(2008,5,23,18,0))
      @response.header['Expire'] = [(Time.now - 60*60).httpdate]

      @response.should be_expired
    end

    it 'should have a #current_age' do
      @response.should respond_to(:current_age)
    end

    it 'should calculate the #current_age' do
      @response.current_age.should == (2 * 60 * 60 + 2)
    end
      
    it 'should know if its #cachable?' do
      @response.should respond_to(:cachable?)
    end

    it 'should normally be cachable' do
      @response.cachable?.should be_true
    end

    def response_with_header(header = {})
      Resourceful::Response.new(200, header, "")
    end

    it 'should not be cachable if the vary header is "*"' do
      r = response_with_header('Vary' => ['*'])
      r.cachable?.should be_false
    end

    it 'should be stale if the Cache-Control header is set to must-revalidate' do
      r = response_with_header('Cache-Control' => ['must-revalidate'])
      r.should be_stale
    end
      
  end

end

