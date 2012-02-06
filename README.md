# ActiveCMIS Release 0.3.0 #
**Homepage**:  <http://xaop.com/labs/activecmis>  
**Git**:       <http://github.com/xaop/activecmis>  
**Documentation**: <http://rdoc.info/github/xaop/activecmis/master/frames>
**Author**:    XAOP bvba  
**Copyright**: 2011
**License**:   MIT License
## Synopsis ##
ActiveCMIS is Ruby library aimed at easing the interaction with various CMIS providers. It creates Ruby objects for CMIS objects, and creates Ruby classes that correspond to CMIS types.
## Features ##
- Read support for all CMIS object types
- Write support and the ability to create new objects.
- Support for paging

## Changes since 0.2.6 ##
The way authentication works has changed. If you previously used ActiveCMIS.connect then you're fine, otherwise the authentication changes will affect you: the authenticate methods on ActiveCMIS::Server and ActiveCMIS::Repository now return a new object, and don't change the authentication on the object itself. You can also specify optional authentication when connecting to a Server, or when calling the repository method.

## Installation ##
If you haven't installed Nokogiri yet it will be installed automatically, you will need a C compiler and the development files for libxml2.

    > gem install active_cmis

ActiveCMIS also depends on ntlm-http for ntlm authentication, unfortunately ntlm-http is broken on ruby 1.9.2
## Usage ##
    require 'active_cmis'
    repository = ActiveCMIS.load_config('configuration', 'optional_filename_for_config')
    f = repository.root_folder
    p f.items.map do |i| i.cmis.name end

And so on ...

Full documentation of the API can be found at [rdoc.info](http://rdoc.info/projects/xaop/activecmis)

A tutorial can be found at [the xaop site](http://xaop.com/labs/activecmis "tutorial")
