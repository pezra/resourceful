require 'resourceful/options_interpretation'
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

    def has_key?(k)
      field_def(k).exists_in?(@raw_fields)
    end

    def each(&blk)
      @raw_fields.each(&blk)
    end
    alias each_field each

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
    class HeaderFieldDef
      include Comparable
      include OptionsInterpretation

      ##
      attr_reader :name

      def initialize(name, options = {})
        @name = name
        extract_opts(options) do |opts|
          @repeatable = opts.extract(:repeatable, :default => false)
          @hop_by_hop = opts.extract(:hop_by_hop, :default => false)
          @modifiable = opts.extract(:modifiable, :default => true)
        end
      end

      def repeatable?
        @repeatable
      end

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
        raw_fields_hash[name] = if repeatable?
                                  Array(value)
                                elsif value.kind_of?(Array)
                                  raise ArgumentError, "#{name} field may only have one value" if value.size > 1
                                  value.first
                                else
                                  value
                                end
      end

      def exists_in?(raw_fields_hash)
        raw_fields_hash.has_key?(name)
      end

      def <=>(another)
        name <=> another.name
      end

      def ==(another)
        name_pattern === another.name
      end
      alias eql? ==

      def ===(another)
        if another.kind_of?(HeaderFieldDef)
          self == another
        else
          name_pattern === another
        end
      end

      def name_pattern
        Regexp.new('^' + name.gsub('-', '[_-]') + '$', Regexp::IGNORECASE)
      end

      def methodized_name
        name.downcase.gsub('-', '_')
      end

      alias to_s name

      def gen_setter(klass)
        klass.class_eval <<-RUBY
          def #{methodized_name}=(val)  # def accept=(val)
            self['#{name}'] = val       #   self['Accept'] = val
          end                           # end
        RUBY
      end

      def gen_getter(klass)
        klass.class_eval <<-RUBY
          def #{methodized_name}  # def accept
            self['#{name}']       #   self['Accept']
          end                     # end
        RUBY
      end

      def gen_canonical_name_const(klass)
        const_name = name.upcase.gsub('-', '_')
        
        klass.const_set(const_name, name)
      end
    end
 
    @@header_field_defs = Set.new

    def self.header_field(name, options = {})
      hfd = HeaderFieldDef.new(name, options)

      @@header_field_defs << hfd

      hfd.gen_getter(self)
      hfd.gen_setter(self)
      hfd.gen_canonical_name_const(self)
    end

    def self.hop_by_hop_headers
      @@header_field_defs.select{|hfd| hfd.hop_by_hop?}
    end

    def self.non_modifiable_headers
      @@header_field_defs.reject{|hfd| hfd.repeatable?}
    end
    
    def field_def(name)
      @@header_field_defs.find{|hfd| hfd === name} || 
        HeaderFieldDef.new(name.to_s.downcase.gsub(/^.|[-_\s]./) { |x| x.upcase }.gsub('_', '-'), :repeatable => true)
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


