# Copied from Rfuzz, w/ the bits I don't need removed.  Thanks Zed.
require 'stringio'

module Resourceful
  # A simple class that using a StringIO object internally to allow for faster
  # and simpler "push back" semantics.  It basically lets you read a random
  # amount from a secondary IO object, parse what is needed, and then anything
  # remaining can be quickly pushed back in one chunk for the next read.
  class PushBackIo
    attr_accessor :secondary

    def initialize(secondary) 
      @secondary = secondary
      @buffer = StringIO.new
      @partial_supported = secondary.respond_to?(:readpartial)
    end

    # Pushes the given string content back onto the stream for the 
    # next read to handle.
    def push(content)
      if content.length > 0
        @buffer.write(content)
      end
    end
    
    # Read from internal buffer. If that is empty read from secondary IO.
    def readpartial(maxlen)
      r = pop(maxlen)
      return r if r
      # buffer was empty, read from secondary IO

      if @partial_supported
        return @secondary.readpartial(maxlen) 
      else
        raise EOFError if closed?
        # We have an open IO from which to read 
  
        return @secondary.read(maxlen)
      end
    end

    # Write `content` to secondary IO
    def write(content)
      @secondary.write(content)
    end

    # Flush secondary IO
    def flush
      @secondary.flush
    end

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
