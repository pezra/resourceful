module Resourceful
  # A RepresentationFactoryDispatcher manages the use one or more
  # representation factories for a particular media type.  It takes an
  # http response and delegates to an appropriate representation
  # factory based on the code of the response.
  class RepresentationFactoryDispatcher
    attr_reader :factories

    def initialize
      @factories = []
    end

    FactoryInfo = Struct.new(:response_codes, :factory)

    # @param [#call] factory The factory that will take a response and
    #   return a representation.
    # @option opts  [#include?] :response_codes Specifies the self of
    #   response codes which can be handled by the specified factory.
    def add_factory(factory, opts)
      opts = Options.for(opts)
      
      response_codes = opts.getopt(:response_codes, (200..499))

      @factories << FactoryInfo.new(response_codes, factory)
    end
    
    def call(a_response)
      appropriate_factory = @factories.find{|factory_info| factory_info.response_codes.include? a_response.code}
      raise NoRepresentationFactoryError unless appropriate_factory

      appropriate_factory.factory.call(a_response)
    end
  end
end
