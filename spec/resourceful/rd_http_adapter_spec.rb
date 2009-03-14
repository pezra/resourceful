require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'resourceful/rd_http_adapter'
require 'facets'

describe Resourceful::RdHttpAdapter do
  describe "#make_request" do
    BASIC_HTTP_RESPONSE = "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHello"

    before do
      @adapter = Resourceful::RdHttpAdapter.new

      @request = request = ""
      @server_conn = stub("server_conn", :close => nil, :flush => nil, :closed? => false, :readpartial => BASIC_HTTP_RESPONSE)
      @server_conn.eigenclass.class_eval do
        define_method(:write) {|req| request << req}
      end

      Socket.stub!(:new).and_return(@server_conn)
    end

    it "should create a socket to correct host" do
      Socket.should_receive(:new).with("foo.invalid", anything)

      @adapter.make_request(:get, u("http://foo.invalid/"))
    end 

    it "should create a socket to correct implicit port" do
      Socket.should_receive(:new).with(anything, 80)

      @adapter.make_request(:get, u("http://foo.invalid/"))
    end 

    it "should create a socket to correct explicit port" do
      Socket.should_receive(:new).with(anything, 8080)
      @adapter.make_request(:get, u("http://foo.invalid:8080/"))
    end 

    def self.it_should_send_correct_method(method)
      it "should send correct request method for #{method} requests" do
        @adapter.make_request(method, u("http://foo.invalid/"))
        request_start_line.should match(/^#{method.to_s.upcase} /i)
      end
    end

    it_should_send_correct_method(:get)
    it_should_send_correct_method(:put)
    it_should_send_correct_method(:post)
    it_should_send_correct_method(:delete)
    it_should_send_correct_method(:head)

    it "should send correct request uri for implicit port" do
      @adapter.make_request(:get, u("http://foo.invalid/"))
      request_start_line.should match(%r{ http://foo.invalid/ }i)
    end

    it "should send correct request uri for explicit port" do
      @adapter.make_request(:get, u("http://foo.invalid:8080/"))
      request_start_line.should match(%r{ http://foo.invalid:8080/ }i)
    end

    it "should send correct HTTP version" do
      @adapter.make_request(:get, u("http://foo.invalid:8080/"))
      request_start_line.should match(%r{ HTTP/1.1$}i)  
    end 

    it "should send specified body" do
      @adapter.make_request(:post, u("http://foo.invalid/"), "hello there")
      request_lines.last.should eql("hello there")
    end 

    it "should have a blank line between the header and body" do
      @adapter.make_request(:post, u("http://foo.invalid/"), "hello there")
      request_lines[-2].should eql("")
    end 

    it "should have a blank line after header even when there is not body" do
      @adapter.make_request(:get, u("http://foo.invalid/"))
      request_lines.last.should eql("")
    end 

    it "should render header fields to request" do
      @adapter.make_request(:get, u("http://foo.invalid/"), nil, {'X-Test-Header' => "a header value"})
      request_lines.should include("X-Test-Header: a header value")
    end 

    it "should render compound header fields to request" do
      @adapter.make_request(:get, u("http://foo.invalid/"), nil, {'X-Test-Header' => ["header value 1", "header value 2"]})
      request_lines.should include("X-Test-Header: header value 1")
      request_lines.should include("X-Test-Header: header value 2")
    end 

    it "should set content-length header field if a body is specified" do
      @adapter.make_request(:post, u("http://foo.invalid/"), "hello there")
      request_lines.should include("Content-Length: 11")
    end 

    it "should not set content-length header field if a body is not specified" do
      @adapter.make_request(:post, u("http://foo.invalid/"))
      request_lines.grep(/Content-Length/).should be_empty
    end 

    it "should flush socket after it is done" do
      @server_conn.should_receive(:flush)
      @adapter.make_request(:get, u("http://foo.invalid/"))
    end

    describe 'simple response' do
      before do
        resp = ["HTTP/1.1 200 OK",
                "Content-Length: 5",
                "X-Test-Header: yer mom",
                "",
                "Hello"].join("\r\n")

        @server_conn.stub!(:readpartial).and_return(resp)
      end

      it "should return correct response status" do
        @adapter.make_request(:get, u("http://foo.invalid/"))[0].should eql(200)
      end 

      it "should return correct headers (content-length)" do
        @adapter.make_request(:get, u("http://foo.invalid/"))[1].should include('Content-Length' => '5')
      end 

      it "should return correct headers (custom)" do
        @adapter.make_request(:get, u("http://foo.invalid/"))[1].should include('X-Test-Header' =>'yer mom')
      end 

      it "should return correct body " do
        @adapter.make_request(:get, u("http://foo.invalid/"))[2].should eql('Hello')
      end 
    end

    describe 'large response' do
      before do
        @bodysize = Resourceful::RdHttpAdapter::CHUNK_SIZE + 100

        resp = http_msg(<<HEAD, 'a' * @bodysize)
HTTP/1.1 200 OK
Content-Length: #{@bodysize}
X-Test-Header: yer mom

HEAD
        
        @server_conn.should_receive(:readpartial).once.ordered.and_return(resp[0,Resourceful::RdHttpAdapter::CHUNK_SIZE])
        @server_conn.should_receive(:read).once.ordered.and_return(resp[Resourceful::RdHttpAdapter::CHUNK_SIZE..-1])
      end

      it "should return correct body " do
        @adapter.make_request(:get, u("http://foo.invalid/"))[2].length.should eql(@bodysize)
      end 
    end

    describe 'incomplete small response' do
      before do

        resp = http_msg(<<HEAD, "hello")
HTTP/1.1 200 OK
Content-Length: 30
X-Test-Header: yer mom

HEAD
        @server_conn.should_receive(:readpartial).once.ordered.and_return(resp)
        @server_conn.should_receive(:read).once.ordered.and_return("")
      end

      it "should return correct body " do
        @adapter.make_request(:get, u("http://foo.invalid/"))[2].should eql("hello")
      end 
    end

    describe 'incomplete large body' do
      before do
        @bodysize = Resourceful::RdHttpAdapter::CHUNK_SIZE + 100

        resp = http_msg(<<HEAD, 'a' * @bodysize)
HTTP/1.1 200 OK
X-Test-Header: yer mom
Content-Length: #{@bodysize * 2}

HEAD

        @server_conn.should_receive(:readpartial).once.ordered.and_return(resp[0,Resourceful::RdHttpAdapter::CHUNK_SIZE])
        @server_conn.should_receive(:read).once.ordered.and_return(resp[Resourceful::RdHttpAdapter::CHUNK_SIZE..-1])
      end

      it "should return the partial body" do
        @adapter.make_request(:get, u("http://foo.invalid/"))[2].should have(@bodysize).items
      end 
    end
    
    describe 'response w/o body' do
      before do

        resp = http_msg(<<RESP)
HTTP/1.1 200 OK
X-Test-Header: yer mom

RESP
        
        @server_conn.should_receive(:readpartial).once.ordered.and_return(resp)
      end

      it "should return correct body " do
        @adapter.make_request(:get, u("http://foo.invalid/"))[2].should eql('')
      end 
    end

    describe 'incomplete header' do
      before do

        resp = http_msg(<<RESP)
HTTP/1.1 200 OK
X-Test-Header: yer mom
RESP

        @server_conn.should_receive(:readpartial).once.and_return(resp)
      end

      it "should raise an execption" do
        lambda {
          @adapter.make_request(:get, u("http://foo.invalid/"))
        }.should raise_error(Resourceful::MalformedServerResponseError)
      end 
    end

    describe 'malformed header' do
      before do

        resp = http_msg(<<RESP)
HTTP/1.1 200 OK
X-Test-Header; yer mom

RESP

        @server_conn.should_receive(:readpartial).once.and_return(resp)
      end

      it "should raise an exception" do
        lambda {
          @adapter.make_request(:get, u("http://foo.invalid/"))
        }.should raise_error(Resourceful::MalformedServerResponseError)
      end 
    end
   
    describe 'chunked response' do
      before do
        resp = http_msg(<<HEAD, "5\r\nhello\r\n5\r\nthere\r\n0\r\n")
HTTP/1.1 200 OK
Transfer-Encoding: chunked

HEAD
 
        @server_conn.stub!(:readpartial).once.and_return(resp)
      end

      it "should have correct body" do
        @adapter.make_request(:get, u("http://foo.invalid/"))[2].should eql('hellothere')
      end
    end

    describe 'malformed chunked response' do
      before do
        resp = http_msg(<<HEAD, "3\r\nhello5\r\nthere")
HTTP/1.1 200 OK
X-Test-Header: yer mom
Transfer-Encoding: chunked

HEAD

        @server_conn.stub!(:readpartial).and_raise(EOFError)
        @server_conn.stub!(:readpartial).and_return(resp)
      end
      
      it "should raise error" do
        lambda {
          @adapter.make_request(:get, u("http://foo.invalid/"))
        }.should raise_error(Resourceful::MalformedServerResponseError)
      end 
    end

    describe 'chunked response w/o final chunck' do
      before do
        resp = http_msg(<<HEAD, "5\r\nhello\r\n5\r\nthere\r\n")
HTTP/1.1 200 OK
Transfer-Encoding: chunked

HEAD

        @server_conn.should_receive(:readpartial).and_return(resp)
      end
      
      it "should raise error" do
        pending
        @adapter.make_request(:get, u("http://foo.invalid/"))[2].should eql('hellothere')
      end 
    end
    

    it "should close socket after it is done" do
      @server_conn.should_receive(:close)
      @adapter.make_request(:post, u("http://foo.invalid/"))
    end
 
    def request_start_line
      request_lines.first
    end

    def request_lines
      @request.split("\r\n", -1)
    end
    
    def http_msg(str, body = nil)
      str.gsub(/\n/m, "\r\n").tap do |s|
        s << body if body
      end
    end
  end 

  def u(uri)
    Addressable::URI.parse(uri)
  end
end 
