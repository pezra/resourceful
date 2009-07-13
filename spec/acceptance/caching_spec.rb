
require File.dirname(__FILE__) + '/../spec_helper'
require 'resourceful'
require 'addressable/template'

describe Resourceful do

  describe "caching" do

    before do
      @http = Resourceful::HttpAccessor.new(:cache_manager => Resourceful::InMemoryCacheManager.new)
      if ENV['SPEC_LOGGING']
        @http.logger = Resourceful::StdOutLogger.new
      end
    end

    def get_with_errors(resource)
      begin
        resp = resource.get
      rescue Resourceful::UnsuccessfulHttpRequestError => e
        resp = e.http_response
      end
      resp
    end

    def uri_plus_params(uri, params = {})
      uri = uri.is_a?(Addressable::URI) ? uri : Addressable::URI.parse(uri)
      uri.query_values = params
      uri
    end

    def uri_for_code(code, params = {})
      template = Addressable::Template.new("http://localhost:3000/code/{code}")
      uri = template.expand("code" => code.to_s)

      uri_plus_params(uri, params)
    end

    describe "response cacheability" do
      Resourceful::Response::NORMALLY_CACHEABLE_RESPONSE_CODES.each do |code|
        describe "response code #{code}" do
          it "should normally be cached" do
            resource = @http.resource(uri_for_code(code))

            resp = get_with_errors(resource)
            resp.should be_cacheable
          end

          it "should not be cached if Vary: *" do
            resource = @http.resource(uri_for_code(200, "Vary" => "*"))

            resp = get_with_errors(resource)
            resp.should_not be_cacheable
          end

          it "should not be cached if Cache-Control: no-cache'" do
            resource = @http.resource(uri_for_code(200, "Cache-Control" => "no-cache"))

            resp = get_with_errors(resource)
            resp.should_not be_cacheable
          end
        end
      end

      # I would prefer to do all other codes, but some of them do some magic stuff (100),
      # so I'll just spot check. 
      [201, 206, 302, 307, 404, 500].each do |code|
        describe "response code #{code}" do
          it "should not normally be cached" do
            resource = @http.resource(uri_for_code(code))

            resp = get_with_errors(resource)
            resp.should_not be_cacheable
          end
          
          it "should be cached if Cache-Control: public" do
            resource = @http.resource(uri_for_code(code, "Cache-Control" => "public"))

            resp = get_with_errors(resource)
            resp.should be_cacheable
          end

          it "should be cached if Cache-Control: private" do
            resource = @http.resource(uri_for_code(code, "Cache-Control" => "private"))

            resp = get_with_errors(resource)
            resp.should be_cacheable
          end
        end
      end

    end

    describe "expiration" do
      it 'should use the cached response if Expire: is in the future' do
        in_the_future = (Time.now + 60).httpdate
        resource = @http.resource(uri_for_code(200, "Expire" => in_the_future))

        resp = resource.get
        resp.should_not be_expired

        resp = resource.get
        resp.should be_ok
        resp.should_not be_authoritative
      end

      it 'should revalidate the cached response if the response is expired' do
        in_the_past = (Time.now - 60).httpdate
        resource = @http.resource(uri_for_code(200, "Expire" => in_the_past))

        resp = resource.get
        resp.should be_expired

        resp = resource.get
        resp.should be_ok
        resp.should be_authoritative
      end
    end

    describe 'authoritative' do

      it "should be authoritative if the response is directly from the server" do
        resource = @http.resource(
          uri_plus_params('http://localhost:3000/', "Cache-Control" => 'max-age=10')
        )

        response  = resource.get
        response.should be_authoritative
      end

      it "should be authoritative if a cached response was revalidated with the server" do
        now = Time.now.httpdate
        resource = @http.resource(
          uri_plus_params('http://localhost:3000/cached', 
                          "modified" => now, 
                          "Cache-Control" => 'max-age=0')
        )

        resource.get
        response = resource.get("Cache-Control" => "max-age=0")
        response.should be_authoritative
      end

      it "should not be authoritative if the cached response was not revalidated" do
        now = Time.now.httpdate
        resource = @http.resource(
          uri_plus_params('http://localhost:3000/cached', 
                          "modified" => now, 
                          "Cache-Control" => 'max-age=10')
        )

        resource.get
        response = resource.get
        response.should_not be_authoritative

      end

    end
    
    describe "Not Modified responses" do
      before do
        now = Time.now.httpdate

        resource = @http.resource(
          uri_plus_params('http://localhost:3000/cached', 
                          "modified" => now, 
                          "Cache-Control" => 'max-age=0')
        )

        @first_response  = resource.get
        @second_response = resource.get("Cache-Control" => "max-age=0") # Force revalidation
      end

      it "should replace the 304 response with whats in the cache" do
        @second_response.code.should == @first_response.code
      end

      it "should provide a body identical to the original response" do
        @second_response.body.should == @first_response.body
      end

      it "should override any cached headers with new ones"
    end

    describe "cache invalidation" do

    end

  end

end

