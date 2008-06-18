# A case-normalizing Hash, adjusting on [] and []=.
# Shamelessly swiped from Rack
module Resourceful
  class Header < Hash
    def initialize(hash={})
      hash.each { |k, v| self[k] = v }
    end

    def to_hash
      {}.replace(self)
    end

    def [](k)
      super capitalize(k)
    end

    def []=(k, v)
      super capitalize(k), v
    end

    def has_key?(k)
      super capitalize(k)
    end

    def capitalize(k)
      k.to_s.downcase.gsub(/^.|[-_\s]./) { |x| x.upcase }
    end
  end
end


