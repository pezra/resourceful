Resourceful
===========

Resourceful provides a convenient Ruby API for making HTTP requests.

Features:

 * GET, PUT, POST and DELETE HTTP requests
 * HTTP Basic and Digest authentication
 * HTTP Caching with pluggable backends
 * Follow redirects based on the results of a callback


Example
=======

Simplest example
---------------

  require 'resourceful'
  http = Resourceful::HttpAccessor.new
  resp = http.resource('http://rubyforge.org').get
  puts resp.body

Get a page requiring HTTP Authentication
----------------------------------------

  basic_handler = Resourceful::BasicAuthenticator.new('My Realm', 'admin', 'secret')
  http.auth_manager.add_auth_hander(basic_handler)
  resp = http.resource('http://example.com/').get
  puts resp.body

Redirection based on callback results
-------------------------------------

Resourceful will by default follow redirects on read requests (GET and HEAD), but not for 
POST, etc. If you want to follow a redirect after a post, you will need to set the resource#on_redirect
callback. If the callback evaluates to true, it will follow the redirect.

  resource = http.resource('http://example.com/redirect_me')
  resource.on_redirect { |req, resp| resp.header['Loction'] =~ /example.com/ }
  resource.get  # Will only follow the redirect if the new location is example.com


Copyright (c) 2008 Absolute Performance, Inc, released under the MIT License.

