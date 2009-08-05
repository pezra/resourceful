# Copied from Rfuzz, w/ the bits I don't need removed.  Thanks Mr Shaw.
require 'stringio'

module Resourceful
  # A simple class that using a StringIO object internally to allow for faster
  # and simpler "push back" semantics.  It basically lets you read a random
  # amount from a secondary IO object, parse what is needed, and then anything
  # remaining can be quickly pushed back in one chunk for the next read.
  class PushBackIo
    extend Forwardable

    attr_accessor :secondary

    module EmulateReadPartialSupport
      def readpartial(maxlen)
        raise EOFError if closed?
                
        read(maxlen)
      end
    end

    def initialize(secondary) 
      @secondary = secondary
      @buffer = StringIO.new
      secondary.extend EmulateReadPartialSupport if not secondary.respond_to?(:readpartial)
    end

    # Pushes the given string content back onto the stream for the 
    # next read to handle.
    def push(content)
      if content.length > 0
        @buffer.write(content)
      end
    end
    
    # Read from internal buffer. If that is empty read from secondary IO.
    #
    # @param [Numeric] maxlen
    #   The maximum number of bytes to read and return
    # @options [Numeric] timeout 
    #   The time, in seconds, to read before giving up.
    def readpartial(maxlen)
      r = pop(maxlen)
      return r if r
      # buffer was empty, read from secondary IO

      @secondary.readpartial(maxlen) 
    end

    # Reads `n` bytes from the secondary IO.  
    #
    # @param [Integer] n the number of bytes to read.
    def read(n)
      (pop(n) || "").tap do |buffer|
        buffer << @secondary.read(n - buffer.length) if buffer.length < n
      end
    end
    
    ##
    # :write
    # Write `content` to secondary IO
    def_delegator :@secondary, :write
    
    ##
    # :flush
    def_delegator :@secondary, :flush
    

    # Close this object and the secondary IO
    def close
      @buffer.string = ""
      @secondary.close
    end

    # Is this IO closed?
    def closed?
      @buffer.size == 0 && @secondary.closed? 
    end

    protected

    # Get some data from the push back buffer.
    def pop(n)
      @buffer.rewind
      o = @buffer.read(n)
      @buffer.string = @buffer.read  # remove the stuff we have returned from the buffer.
      return o
    end
  end
end
