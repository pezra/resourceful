require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'resourceful/rd_http_adapter'
require 'facets'

describe Resourceful::RdHttpAdapter do
  describe "#make_request" do
    BASIC_HTTP_RESPONSE = "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHello"
    NONSTD_PORT_URL = Addressable::URI.parse("http://foo.invalid:8080/")
    STD_PORT_URL = Addressable::URI.parse("http://foo.invalid/")
    
    before do
      @adapter = Resourceful::RdHttpAdapter.new

      @request_string = request_string = ""

      @server_conn = stub("server_conn", :close => nil, :flush => nil, :closed? => false, :readpartial => BASIC_HTTP_RESPONSE)
      @server_conn.eigenclass.class_eval do
        define_method(:write) {|req| request_string << req}
      end

      @request = mock(Resourceful::Request, :uri => STD_PORT_URL, :method => :get, :body => nil, :header => Resourceful::Header.new)
      @post_request = mock(Resourceful::Request, :uri => STD_PORT_URL, :method => :post, :body => 'hello there', :header => Resourceful::Header.new)

      Socket.stub!(:new).and_return(@server_conn)
    end

    it "should create a socket to correct host" do
      Socket.should_receive(:new).with("foo.invalid", anything)

      @adapter.make_request(@request)
    end 

    it "should create a socket to correct implicit port" do
      Socket.should_receive(:new).with(anything, 80)

      @adapter.make_request(@request)
    end 

    it "should create a socket to correct explicit port" do
      @request.stub!(:uri).and_return(NONSTD_PORT_URL)
      Socket.should_receive(:new).with(anything, 8080)

      @adapter.make_request(@request)
    end 

    def self.it_should_send_correct_method(method)
      it "should send correct request method for #{method} requests" do
        @request.stub!(:method).and_return(method)
        @adapter.make_request(@request)
        request_start_line.should match(/^#{method.to_s.upcase} /i)
      end
    end

    it_should_send_correct_method(:get)
    it_should_send_correct_method(:put)
    it_should_send_correct_method(:post)
    it_should_send_correct_method(:delete)
    it_should_send_correct_method(:head)

    it "should send correct request uri for implicit port" do
      @adapter.make_request(@request)
      request_start_line.should match(%r{ http://foo.invalid/ }i)
    end

    it "should send correct request uri for explicit port" do
      @request.stub!(:uri).and_return(NONSTD_PORT_URL)
      @adapter.make_request(@request)
      request_start_line.should match(%r{ http://foo.invalid:8080/ }i)
    end

    it "should send correct HTTP version" do
      @adapter.make_request(@request)
      request_start_line.should match(%r{ HTTP/1.1$}i)  
    end 

    it "should send specified body" do
      @adapter.make_request(@post_request)
      request_lines.last.should eql("hello there")
    end 

    it "should have a blank line between the header and body" do
      @adapter.make_request(@post_request)
      request_lines[-2].should eql("")
    end 

    it "should have a blank line after header even when there is not body" do
      @adapter.make_request(@request)
      request_lines.last.should eql("")
    end 

    it "should render header fields to request" do
      @request.header['X-Test-Header'] = 'a header value'
      @adapter.make_request(@request)
      request_lines.should include("X-Test-Header: a header value")
    end 

    it "should render compound header fields to request" do
      @request.header['X-Test-Header'] = ["header value 1", "header value 2"]
      @adapter.make_request(@request)
      request_lines.should include("X-Test-Header: header value 1")
      request_lines.should include("X-Test-Header: header value 2")
    end 

    it "should set content-length header field if a body is specified" do
      @adapter.make_request(@post_request)
      request_lines.should include("Content-Length: 11")
    end 

    it "should not set content-length header field if a body is not specified" do
      @post_request.stub!(:body).and_return(nil)
      @adapter.make_request(@post_request)
      request_lines.grep(/Content-Length/).should be_empty
    end 

    it "should flush socket after it is done" do
      @server_conn.should_receive(:flush)
      @adapter.make_request(@request)
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

      it "should return Hash-ish" do
        @adapter.make_request(@request).should respond_to(:[])
      end 

      def have_field(key, value)
        key_matcher = Regexp.compile(key.gsub(/-/, '[-_]'), Regexp::IGNORECASE)

        simple_matcher("header matcher") do |given, matcher|
          matcher.failure_message = "Expected #{given.inspect} to include key #{key.inspect} with #{value.inspect}"
          header = given

          actual_key = header.keys.find{|a_key| key_matcher === a_key}

          actual_key && header[actual_key] == value
        end
      end

      it "should return correct response status" do
        @adapter.make_request(@request).status.should eql(200)
      end 

      it "should return headers" do
        @adapter.make_request(@request).header.should be_kind_of(Hash)
      end

      it "should return correct headers (content-length)" do
        @adapter.make_request(@request).header.should have_field('Content-Length','5')
      end 

      it "should return correct headers (custom)" do
        @adapter.make_request(@request).header.should have_field('X-Test-Header', 'yer mom')
      end 

      it "should return correct body " do
        @adapter.make_request(@request).body.should eql('Hello')
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
        @adapter.make_request(@request)[:body].length.should eql(@bodysize)
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
        @adapter.make_request(@request)[:body].should eql("hello")
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
        @adapter.make_request(@request)[:body].length.should eql(@bodysize)
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
        @adapter.make_request(@request)[:body].should eql('')
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
          @adapter.make_request(@request)
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
          @adapter.make_request(@request)
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
        @adapter.make_request(@request)[:body].should eql('hellothere')
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
          @adapter.make_request(@request)
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
        @adapter.make_request(@request)[:body].should eql('hellothere')
      end 
    end
    

    it "should close socket after it is done" do
      @server_conn.should_receive(:close)
      @adapter.make_request(@post_request)
    end
 
    def request_start_line
      request_lines.first
    end

    def request_lines
      @request_string.split("\r\n", -1)
    end
    
    def http_msg(str, body = nil)
      str.gsub(/\n/m, "\r\n").tap do |s|
        s << body if body
      end
    end
  end 

end 
