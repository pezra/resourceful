
# line 1 "lib/resourceful/rd_http_adapter/http_response_parser.rl"
# Copyright (c) 2005 Zed A. Shaw
# You can redistribute it and/or modify it under the same terms as Ruby.

#define LEN(AT, FPC) (FPC - buffer - parser->AT)
#define MARK(M,FPC) (parser->M = (FPC) - buffer)
#define PTR_TO(F) (buffer + parser->F)
#define L(M) fprintf(stderr, "" # M "\n");


# machine

# line 93 "lib/resourceful/rd_http_adapter/http_response_parser.rl"


module Resourceful
  class RdHttpAdapter
    class ParsedHttpResponseHeader
      attr_accessor :status_code, :reason_phrase, :http_version, :header_fields, :remainder
      def initialize
        @header_fields = []
      end
    end

    class IncompleteHeaderException < Exception
    end

    class HttpResponseParser
      attr_reader :result, :data

      def initialize
        @result = ParsedHttpResponseHeader.new
        @done = false

        
# line 38 "lib/resourceful/rd_http_adapter/http_response_parser.rb"
class << self
	attr_accessor :_http_response_parser_actions
	private :_http_response_parser_actions, :_http_response_parser_actions=
end
self._http_response_parser_actions = [
	0, 1, 0, 1, 1, 1, 2, 1, 
	3, 1, 4, 1, 5, 1, 6, 1, 
	7, 1, 8, 1, 10, 2, 2, 3, 
	2, 3, 4, 2, 9, 10, 2, 10, 
	9, 3, 2, 3, 4
]

class << self
	attr_accessor :_http_response_parser_key_offsets
	private :_http_response_parser_key_offsets, :_http_response_parser_key_offsets=
end
self._http_response_parser_key_offsets = [
	0, 0, 10, 11, 19, 20, 28, 29, 
	44, 62, 77, 94, 109, 127, 142, 159, 
	174, 192, 207, 224, 225, 226, 227, 228, 
	230, 233, 235, 238, 240, 243, 243, 244, 
	245, 261, 277, 279, 280
]

class << self
	attr_accessor :_http_response_parser_trans_keys
	private :_http_response_parser_trans_keys, :_http_response_parser_trans_keys=
end
self._http_response_parser_trans_keys = [
	13, 48, 59, 72, 49, 57, 65, 70, 
	97, 102, 10, 13, 59, 48, 57, 65, 
	70, 97, 102, 10, 13, 59, 48, 57, 
	65, 70, 97, 102, 10, 33, 124, 126, 
	35, 39, 42, 43, 45, 46, 48, 57, 
	65, 90, 94, 122, 13, 33, 59, 61, 
	124, 126, 35, 39, 42, 43, 45, 46, 
	48, 57, 65, 90, 94, 122, 33, 124, 
	126, 35, 39, 42, 43, 45, 46, 48, 
	57, 65, 90, 94, 122, 13, 33, 59, 
	124, 126, 35, 39, 42, 43, 45, 46, 
	48, 57, 65, 90, 94, 122, 33, 124, 
	126, 35, 39, 42, 43, 45, 46, 48, 
	57, 65, 90, 94, 122, 13, 33, 59, 
	61, 124, 126, 35, 39, 42, 43, 45, 
	46, 48, 57, 65, 90, 94, 122, 33, 
	124, 126, 35, 39, 42, 43, 45, 46, 
	48, 57, 65, 90, 94, 122, 13, 33, 
	59, 124, 126, 35, 39, 42, 43, 45, 
	46, 48, 57, 65, 90, 94, 122, 33, 
	124, 126, 35, 39, 42, 43, 45, 46, 
	48, 57, 65, 90, 94, 122, 13, 33, 
	59, 61, 124, 126, 35, 39, 42, 43, 
	45, 46, 48, 57, 65, 90, 94, 122, 
	33, 124, 126, 35, 39, 42, 43, 45, 
	46, 48, 57, 65, 90, 94, 122, 13, 
	33, 59, 124, 126, 35, 39, 42, 43, 
	45, 46, 48, 57, 65, 90, 94, 122, 
	84, 84, 80, 47, 48, 57, 46, 48, 
	57, 48, 57, 32, 48, 57, 48, 57, 
	32, 48, 57, 13, 10, 13, 33, 124, 
	126, 35, 39, 42, 43, 45, 46, 48, 
	57, 65, 90, 94, 122, 33, 58, 124, 
	126, 35, 39, 42, 43, 45, 46, 48, 
	57, 65, 90, 94, 122, 13, 32, 13, 
	0
]

class << self
	attr_accessor :_http_response_parser_single_lengths
	private :_http_response_parser_single_lengths, :_http_response_parser_single_lengths=
end
self._http_response_parser_single_lengths = [
	0, 4, 1, 2, 1, 2, 1, 3, 
	6, 3, 5, 3, 6, 3, 5, 3, 
	6, 3, 5, 1, 1, 1, 1, 0, 
	1, 0, 1, 0, 1, 0, 1, 1, 
	4, 4, 2, 1, 0
]

class << self
	attr_accessor :_http_response_parser_range_lengths
	private :_http_response_parser_range_lengths, :_http_response_parser_range_lengths=
end
self._http_response_parser_range_lengths = [
	0, 3, 0, 3, 0, 3, 0, 6, 
	6, 6, 6, 6, 6, 6, 6, 6, 
	6, 6, 6, 0, 0, 0, 0, 1, 
	1, 1, 1, 1, 1, 0, 0, 0, 
	6, 6, 0, 0, 0
]

class << self
	attr_accessor :_http_response_parser_index_offsets
	private :_http_response_parser_index_offsets, :_http_response_parser_index_offsets=
end
self._http_response_parser_index_offsets = [
	0, 0, 8, 10, 16, 18, 24, 26, 
	36, 49, 59, 71, 81, 94, 104, 116, 
	126, 139, 149, 161, 163, 165, 167, 169, 
	171, 174, 176, 179, 181, 184, 185, 187, 
	189, 200, 211, 214, 216
]

class << self
	attr_accessor :_http_response_parser_indicies
	private :_http_response_parser_indicies, :_http_response_parser_indicies=
end
self._http_response_parser_indicies = [
	0, 2, 4, 5, 3, 3, 3, 1, 
	6, 1, 7, 9, 8, 8, 8, 1, 
	10, 1, 11, 12, 8, 8, 8, 1, 
	13, 1, 14, 14, 14, 14, 14, 14, 
	14, 14, 14, 1, 15, 16, 17, 18, 
	16, 16, 16, 16, 16, 16, 16, 16, 
	1, 19, 19, 19, 19, 19, 19, 19, 
	19, 19, 1, 20, 21, 22, 21, 21, 
	21, 21, 21, 21, 21, 21, 1, 23, 
	23, 23, 23, 23, 23, 23, 23, 23, 
	1, 24, 25, 26, 27, 25, 25, 25, 
	25, 25, 25, 25, 25, 1, 28, 28, 
	28, 28, 28, 28, 28, 28, 28, 1, 
	29, 30, 31, 30, 30, 30, 30, 30, 
	30, 30, 30, 1, 32, 32, 32, 32, 
	32, 32, 32, 32, 32, 1, 33, 34, 
	35, 36, 34, 34, 34, 34, 34, 34, 
	34, 34, 1, 37, 37, 37, 37, 37, 
	37, 37, 37, 37, 1, 38, 39, 40, 
	39, 39, 39, 39, 39, 39, 39, 39, 
	1, 41, 1, 42, 1, 43, 1, 44, 
	1, 45, 1, 46, 45, 1, 47, 1, 
	48, 47, 1, 49, 1, 50, 51, 1, 
	52, 54, 53, 55, 1, 56, 57, 57, 
	57, 57, 57, 57, 57, 57, 57, 1, 
	58, 59, 58, 58, 58, 58, 58, 58, 
	58, 58, 1, 61, 62, 60, 64, 63, 
	1, 0
]

class << self
	attr_accessor :_http_response_parser_trans_targs
	private :_http_response_parser_trans_targs, :_http_response_parser_trans_targs=
end
self._http_response_parser_trans_targs = [
	2, 0, 3, 5, 15, 19, 36, 4, 
	5, 11, 36, 6, 7, 36, 8, 6, 
	8, 7, 9, 10, 6, 10, 7, 12, 
	4, 12, 11, 13, 14, 4, 14, 11, 
	16, 2, 16, 15, 17, 18, 2, 18, 
	15, 20, 21, 22, 23, 24, 25, 26, 
	27, 28, 29, 28, 30, 30, 31, 32, 
	6, 33, 33, 34, 35, 31, 34, 35, 
	31
]

class << self
	attr_accessor :_http_response_parser_trans_actions
	private :_http_response_parser_trans_actions, :_http_response_parser_trans_actions=
end
self._http_response_parser_trans_actions = [
	0, 0, 1, 1, 0, 1, 27, 17, 
	0, 17, 30, 17, 17, 19, 3, 33, 
	0, 33, 21, 7, 9, 0, 9, 3, 
	33, 0, 33, 21, 7, 9, 0, 9, 
	3, 33, 0, 33, 21, 7, 9, 0, 
	9, 0, 0, 0, 0, 0, 0, 0, 
	15, 1, 13, 0, 1, 0, 11, 0, 
	0, 3, 0, 5, 7, 24, 7, 0, 
	9
]

class << self
	attr_accessor :http_response_parser_start
end
self.http_response_parser_start = 1;
class << self
	attr_accessor :http_response_parser_first_final
end
self.http_response_parser_first_final = 36;
class << self
	attr_accessor :http_response_parser_error
end
self.http_response_parser_error = 0;

class << self
	attr_accessor :http_response_parser_en_main
end
self.http_response_parser_en_main = 1;


# line 115 "lib/resourceful/rd_http_adapter/http_response_parser.rl"
     end

      def execute(buffer)
        if @data
          # second part of header
          puts "SECOND PART"
          @data = marked_data(@data.length) + buffer
          @mark = 0
        else
          @data = buffer
          
# line 240 "lib/resourceful/rd_http_adapter/http_response_parser.rb"
begin
	p ||= 0
	pe ||= data.length
	cs = http_response_parser_start
end

# line 126 "lib/resourceful/rd_http_adapter/http_response_parser.rl"
        end
p @data

        data = @data
        
# line 253 "lib/resourceful/rd_http_adapter/http_response_parser.rb"
begin
	_klen, _trans, _keys, _acts, _nacts = nil
	_goto_level = 0
	_resume = 10
	_eof_trans = 15
	_again = 20
	_test_eof = 30
	_out = 40
	while true
	_trigger_goto = false
	if _goto_level <= 0
	if p == pe
		_goto_level = _test_eof
		next
	end
	if cs == 0
		_goto_level = _out
		next
	end
	end
	if _goto_level <= _resume
	_keys = _http_response_parser_key_offsets[cs]
	_trans = _http_response_parser_index_offsets[cs]
	_klen = _http_response_parser_single_lengths[cs]
	_break_match = false
	
	begin
	  if _klen > 0
	     _lower = _keys
	     _upper = _keys + _klen - 1

	     loop do
	        break if _upper < _lower
	        _mid = _lower + ( (_upper - _lower) >> 1 )

	        if data[p] < _http_response_parser_trans_keys[_mid]
	           _upper = _mid - 1
	        elsif data[p] > _http_response_parser_trans_keys[_mid]
	           _lower = _mid + 1
	        else
	           _trans += (_mid - _keys)
	           _break_match = true
	           break
	        end
	     end # loop
	     break if _break_match
	     _keys += _klen
	     _trans += _klen
	  end
	  _klen = _http_response_parser_range_lengths[cs]
	  if _klen > 0
	     _lower = _keys
	     _upper = _keys + (_klen << 1) - 2
	     loop do
	        break if _upper < _lower
	        _mid = _lower + (((_upper-_lower) >> 1) & ~1)
	        if data[p] < _http_response_parser_trans_keys[_mid]
	          _upper = _mid - 2
	        elsif data[p] > _http_response_parser_trans_keys[_mid+1]
	          _lower = _mid + 2
	        else
	          _trans += ((_mid - _keys) >> 1)
	          _break_match = true
	          break
	        end
	     end # loop
	     break if _break_match
	     _trans += _klen
	  end
	end while false
	_trans = _http_response_parser_indicies[_trans]
	cs = _http_response_parser_trans_targs[_trans]
	if _http_response_parser_trans_actions[_trans] != 0
		_acts = _http_response_parser_trans_actions[_trans]
		_nacts = _http_response_parser_actions[_acts]
		_acts += 1
		while _nacts > 0
			_nacts -= 1
			_acts += 1
			case _http_response_parser_actions[_acts - 1]
when 0 then
# line 14 "lib/resourceful/rd_http_adapter/http_response_parser.rl"
		begin
 @mark = p 		end
# line 14 "lib/resourceful/rd_http_adapter/http_response_parser.rl"
when 1 then
# line 16 "lib/resourceful/rd_http_adapter/http_response_parser.rl"
		begin
 
    @mark = p
  		end
# line 16 "lib/resourceful/rd_http_adapter/http_response_parser.rl"
when 2 then
# line 20 "lib/resourceful/rd_http_adapter/http_response_parser.rl"
		begin
 
    extract_field_name(p)
  		end
# line 20 "lib/resourceful/rd_http_adapter/http_response_parser.rl"
when 3 then
# line 24 "lib/resourceful/rd_http_adapter/http_response_parser.rl"
		begin
 
    @mark = p
  		end
# line 24 "lib/resourceful/rd_http_adapter/http_response_parser.rl"
when 4 then
# line 28 "lib/resourceful/rd_http_adapter/http_response_parser.rl"
		begin
 
    extract_field_value(p)
  		end
# line 28 "lib/resourceful/rd_http_adapter/http_response_parser.rl"
when 5 then
# line 32 "lib/resourceful/rd_http_adapter/http_response_parser.rl"
		begin
 
    extract_reason_phrase(p)
  		end
# line 32 "lib/resourceful/rd_http_adapter/http_response_parser.rl"
when 6 then
# line 36 "lib/resourceful/rd_http_adapter/http_response_parser.rl"
		begin
 
    extract_status_code(p)
  		end
# line 36 "lib/resourceful/rd_http_adapter/http_response_parser.rl"
when 7 then
# line 40 "lib/resourceful/rd_http_adapter/http_response_parser.rl"
		begin
	
    extract_http_version(p)
  		end
# line 40 "lib/resourceful/rd_http_adapter/http_response_parser.rl"
when 8 then
# line 44 "lib/resourceful/rd_http_adapter/http_response_parser.rl"
		begin

#    parser->chunk_size(parser->data, PTR_TO(mark), LEN(mark, fpc));
  		end
# line 44 "lib/resourceful/rd_http_adapter/http_response_parser.rl"
when 9 then
# line 48 "lib/resourceful/rd_http_adapter/http_response_parser.rl"
		begin

#    parser->last_chunk(parser->data, NULL, 0);
  		end
# line 48 "lib/resourceful/rd_http_adapter/http_response_parser.rl"
when 10 then
# line 52 "lib/resourceful/rd_http_adapter/http_response_parser.rl"
		begin
 
    @done = true
    extract_remainder(p)

#    parser->body_start = fpc - buffer + 1; 
#    if(parser->header_done != NULL)
#      parser->header_done(parser->data, fpc + 1, pe - fpc - 1);
#    fbreak;
  		end
# line 52 "lib/resourceful/rd_http_adapter/http_response_parser.rl"
# line 415 "lib/resourceful/rd_http_adapter/http_response_parser.rb"
			end # action switch
		end
	end
	if _trigger_goto
		next
	end
	end
	if _goto_level <= _again
	if cs == 0
		_goto_level = _out
		next
	end
	p += 1
	if p != pe
		_goto_level = _resume
		next
	end
	end
	if _goto_level <= _test_eof
	end
	if _goto_level <= _out
		break
	end
	end
	end

# line 131 "lib/resourceful/rd_http_adapter/http_response_parser.rl"

pp result

        raise IncompleteHeaderException unless done?

        @result
      end

      def done?
        @done
      end

      def self.marked_component(name)
        class_eval <<-EXTRACTOR
          def extract_#{name}(end_idx)
            result.#{name} = marked_data(end_idx)
            clear_mark
          end         
        EXTRACTOR
      end

      marked_component(:http_version)
      marked_component(:status_code)
      marked_component(:reason_phrase)
      
      def extract_field_name(end_idx)
        result.header_fields << [marked_data(end_idx)]
        clear_mark
      end

      def extract_field_value(end_idx)
        result.header_fields.last << marked_data(end_idx)
        clear_mark
      end
      
      def extract_remainder(header_end_idx)
        result.remainder = data[header_end_idx+1, data.length - header_end_idx]
      end
      
      protected

      def marked_data(end_idx)
        data[@mark, end_idx - @mark]
      end

      def clear_mark
        @mark = nil
      end
    end
  end
end

