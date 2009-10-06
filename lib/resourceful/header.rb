require 'options'
require 'set'

# Represents the header fields of an HTTP message.  To access a field
# you can use `#[]` and `#[]=`.  For example, to get the content type
# of a response you can do
# 
#     response.header['Content-Type']  # => "application/xml"
#
# Lookups and modifications done in this way are case insensitive, so
# 'Content-Type', 'content-type' and :content_type are all equivalent.
#
# Multi-valued fields
# -------------------
#
# Multi-value fields (e.g. Accept) are always returned as an Array
# regardless of the number of values, if the field is present.
# Single-value fields (e.g. Content-Type) are always returned as
# strings. The multi/single valueness of a header field is determined
# by the way it is defined in the HTTP spec.  Unknown fields are
# treated as multi-valued.
#
# (This behavior is new in 0.6 and may be slightly incompatible with
# the way previous versions worked in some situations.)
#
# For example
#
#     h = Resourceful::Header.new
#     h['Accept'] = "application/xml"
#     h['Accept']                      # => ["application/xml"]
#
module Resourceful
  class Header
    include Enumerable
    
    def initialize(hash={})
      @raw_fields = {}
      hash.each { |k, v| self[k] = v }
    end

    def to_hash
      @raw_fields.dup
    end

    def [](k)
      field_def(k).get_from(@raw_fields)
    end

    def []=(k, v)
      field_def(k).set_to(v, @raw_fields)
    end

    def delete(k)
      field_def(k).delete(@raw_fields)
    end

    def has_key?(k)
      field_def(k).exists_in?(@raw_fields)
    end
    alias has_field? has_key?

    def each(&blk)
      @raw_fields.each(&blk)
    end

    # Iterates through the fields with values provided as message
    # ready strings.
    def each_field(&blk)
      each do |k,v|
        str_v = if field_def(k).multivalued?
                  v.join(', ')
                else
                  v.to_s
                end

        yield k, str_v
      end
    end

    def merge!(another)
      another.each do |k,v|
        self[k] = v
      end
      self
    end

    def delete(k)
      @raw_fields.delete(field_def(k).name)
    end

    def merge(another)
      self.class.new(self).merge!(another)
    end

    def reverse_merge(another)
      self.class.new(another).merge!(self)
    end

    def dup
      self.class.new(@raw_fields.dup)
    end

    # Class to handle the details of each type of field.
    class FieldDesc
      include Comparable
      
      ##
      attr_reader :name
      
      # Create a new header field descriptor.
      #
      # @param [String] name  The canonical name of this field.
      #
      # @param [Hash] options hash containing extra information about
      #   this header fields.  Valid keys are:
      #   
      #     `:multivalued`
      #     `:multivalue`
      #     `:repeatable`
      #     :   Values of this field are comma separated list of values.  
      #         (n#VALUE per HTTP spec.) Default: false
      #
      #     `:hop_by_hop`
      #     :   True if the header is a hop-by-hop header. Default: false
      #
      #     `:modifiable`
      #     :   False if the header should not be modified by intermediates or caches. Default: true
      #
      def initialize(name, options = {})
        @name = name
        options = Options.for(options).validate(:repeatable, :hop_by_hop, :modifiable)
        
        @repeatable = options.getopt([:repeatable, :multivalue, :multivalued]) || false
        @hop_by_hop = options.getopt(:hop_by_hop) || false
        @modifiable = options.getopt(:modifiable, true)
      end
      
      def repeatable?
        @repeatable
      end
      alias multivalued? repeatable?
      
      def hop_by_hop?
        @hop_by_hop
      end
      
      def modifiable?
        @modifiable
      end
      
      def get_from(raw_fields_hash)
        raw_fields_hash[name]
      end
      
      def set_to(value, raw_fields_hash)
        raw_fields_hash[name] = if multivalued?
                                  Array(value).map{|v| v.split(/,\s*/)}.flatten
                                elsif value.kind_of?(Array)
                                  raise ArgumentError, "#{name} field may only have one value" if value.size > 1
                                  value.first
                                else
                                  value
                                end
      end
      
      def delete(raw_fields_hash)
        raw_fields_hash.delete(name)
      end
      
      def exists_in?(raw_fields_hash)
        raw_fields_hash.has_key?(name)
      end
      
      def <=>(another)
        name <=> another.name
      end
      
      def ==(another)
        name_pattern === another.to_s
      end
      alias eql? ==
        
      def ===(another)
        if another.kind_of?(FieldDesc)
          self == another
        else
          name_pattern === another
        end
      end
      
      def name_pattern
        @name_pattern ||= Regexp.new('^' + name.gsub('-', '[_-]') + '$', Regexp::IGNORECASE)
      end
      
      def methodized_name
        @methodized_name ||= name.downcase.gsub('-', '_')
      end
        
      def constantized_name
        @constantized_name ||= name.upcase.gsub('-', '_')
      end
      
      alias to_s name
      
      def accessor_module 
        @accessor_module ||= begin
                               Module.new.tap{|m| m.module_eval(<<-RUBY)}
                                 #{constantized_name} = '#{name}'
  
                                 def #{methodized_name}        # def accept
                                   self[#{constantized_name}]  #   self[ACCEPT]
                                 end                           # end
         
                                 def #{methodized_name}=(val)        # def accept=(val)
                                   self[#{constantized_name}] = val  #   self[ACCEPT] = val
                                 end                                 # end
                               RUBY
                             end
      end

      def hash
        @name.hash
      end
        
      # Yields each commonly used lookup key for this header field.
      def lookup_keys(&blk)
        yield name
        yield name.upcase
        yield name.downcase
        yield methodized_name
        yield methodized_name.to_sym
        yield constantized_name
        yield constantized_name.to_sym
      end
    end # FieldDesc
    
    @@known_fields = Set.new
    @@known_fields_lookup = Hash.new

    # Declares a common header field.  Header fields do not have to be
    # defined this way but accessing them is easier, safer and faster
    # if you do.  Declaring a field does the following things:
    #
    #  * defines accessor methods (e.g. `#content_type` and
    #    `#content_type=`) on `Header`
    #  
    #  * defines constant that can be used to reference there field
    #    name (e.g. `some_header[Header::CONTENT_TYPE]`)
    #  
    #  * includes the field in the appropriate *_fields groups (e.g. `Header.non_modifiable_fields`)
    #
    #  * provides improved multiple value parsing
    #
    # Create a new header field descriptor.
    #
    # @param [String] name  The canonical name of this field.
    #
    # @param [Hash] options hash containing extra information about
    #   this header fields.  Valid keys are:
    #   
    #     `:multivalued`
    #     `:multivalue`
    #     `:repeatable`
    #     :   Values of this field are comma separated list of values.  
    #         (n#VALUE per HTTP spec.) Default: false
    #
    #     `:hop_by_hop`
    #     :   True if the header is a hop-by-hop header. Default: false
    #
    #     `:modifiable`
    #     :   False if the header should not be modified by intermediates or caches. Default: true
    #
    def self.header_field(name, options = {})
      hfd = FieldDesc.new(name, options)
      
      @@known_fields << hfd      
      hfd.lookup_keys do |a_key|
        @@known_fields_lookup[a_key] = hfd
      end

      include(hfd.accessor_module)
    end
    
    def self.hop_by_hop_fields
      @@known_fields.select{|hfd| hfd.hop_by_hop?}
    end
    
    def self.non_modifiable_fields
      @@known_fields.reject{|hfd| hfd.modifiable?}
    end

    protected

    # ---
    #
    # We have to fall back on a slow iteration to find the header
    # field some times because field names are
    def field_def(name)
      @@known_fields_lookup[name] ||  # the fast way
        @@known_fields.find{|hfd| hfd === name} ||  # the slow way
        FieldDesc.new(name.to_s.downcase.gsub(/^.|[-_\s]./) { |x| x.upcase }.gsub('_', '-'), :repeatable => true)  # make up as we go
    end

    header_field('Accept', :repeatable => true)
    header_field('Accept-Charset', :repeatable => true)
    header_field('Accept-Encoding', :repeatable => true)
    header_field('Accept-Language', :repeatable => true)
    header_field('Accept-Ranges', :repeatable => true)
    header_field('Age')
    header_field('Allow', :repeatable => true)
    header_field('Authorization', :repeatable => true)
    header_field('Cache-Control', :repeatable => true)
    header_field('Connection', :hop_by_hop => true)
    header_field('Content-Encoding', :repeatable => true)
    header_field('Content-Language', :repeatable => true)
    header_field('Content-Length')
    header_field('Content-Location', :modifiable => false)
    header_field('Content-MD5', :modifiable => false)
    header_field('Content-Range')
    header_field('Content-Type')
    header_field('Date')
    header_field('ETag', :modifiable => false)
    header_field('Expect', :repeatable => true)
    header_field('Expires', :modifiable => false)
    header_field('From')
    header_field('Host')
    header_field('If-Match', :repeatable => true)
    header_field('If-Modified-Since')
    header_field('If-None-Match', :repeatable => true)
    header_field('If-Range')
    header_field('If-Unmodified-Since')
    header_field('Keep-Alive', :hop_by_hop => true)
    header_field('Last-Modified', :modifiable => false)
    header_field('Location')
    header_field('Max-Forwards')
    header_field('Pragma', :repeatable => true)
    header_field('Proxy-Authenticate', :hop_by_hop => true)
    header_field('Proxy-Authorization', :hop_by_hop => true)
    header_field('Range')
    header_field('Referer')
    header_field('Retry-After')
    header_field('Server')
    header_field('TE', :repeatable => true, :hop_by_hop => true)
    header_field('Trailer', :repeatable => true, :hop_by_hop => true)
    header_field('Transfer-Encoding', :repeatable => true, :hop_by_hop => true)
    header_field('Upgrade', :repeatable => true, :hop_by_hop => true)
    header_field('User-Agent')
    header_field('Vary', :repeatable => true)
    header_field('Via', :repeatable => true)
    header_field('Warning', :repeatable => true)
    header_field('WWW-Authenticate', :repeatable => true)
  end
end


