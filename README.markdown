Resourceful
===========

Resourceful provides a convenient Ruby API for making HTTP requests.

Features:

 * GET, PUT, POST and DELETE HTTP requests
 * HTTP Basic and Digest authentication
 * HTTP Caching with pluggable backends
 * Follow redirects based on the results of a callback

More Info
=========

 * Source: [Github](http://github.com/paul/resourceful/tree/master)
 * Bug Tracking: [Lighthouse](http://resourceful.lighthouseapp.com)
 * Project Page: [Rubyforge](http://rubyforge.org/projects/resourceful/)
 * Documentation: [API Docs](http://resourceful.rubyforge.org)

Examples
========

Getting started
---------------

    gem install resourceful

Simplest example
---------------

    require 'resourceful'
    resp = Resourceful.get('http://rubyforge.org')
    puts resp.body

Get a page requiring HTTP Authentication
----------------------------------------

    my_realm_authenticator = Resourceful::BasicAuthenticator.new('My Realm', 'admin', 'secret')
    http = Resourceful::HttpAccessor.new(:authenticator => my_realm_authenticator)
    resp = http.resource('http://example.com/').get
    puts resp.body

Redirection based on callback results
-------------------------------------

Resourceful will by default follow redirects on read requests (GET and HEAD), but not for
POST, etc. If you want to follow a redirect after a post, you will need to set the resource#on_redirect
callback. If the callback evaluates to true, it will follow the redirect.

    resource = http.resource('http://example.com/redirect_me')
    resource.on_redirect { |req, resp| resp.header['Location'] =~ /example.com/ }
    resource.get  # Will only follow the redirect if the new location is example.com

Post a URL encoded form
-----------------------

     require 'resourceful'
     http = Resourceful::HttpAccessor.new
     resp = http.resource('http://mysite.example/service').
              post(Resourceful::UrlencodedFormData.new(:hostname => 'test', :level => 'super'))

Post a Mulitpart form with a file
-----------------------

     require 'resourceful'
     http = Resourceful::HttpAccessor.new
     form_data = Resourceful::MultipartFormData.new(:username => 'me')
     form_data.add_file('avatar', '/tmp/my_avatar.png', 'image/png')
     resp = http.resource('http://mysite.example/service').post(form_data)

Put an XML document
-------------------

     require 'resourceful'
     http = Resourceful::HttpAccessor.new
     resp = http.resource('http://mysite.example/service').
              put('<?xml version="1.0"?><test/>', :content_type => 'application/xml')

Delete a resource
-----------------

     require 'resourceful'
     http = Resourceful::HttpAccessor.new
     resp = http.resource('http://mysite.example/service').delete


Copyright
---------

Copyright (c) 2008 Absolute Performance, Inc, Peter Williams.  Released under the MIT License.

