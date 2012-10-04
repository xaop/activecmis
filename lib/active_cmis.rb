require 'nokogiri'
require 'net/http'
require 'net/https'
#require 'net/ntlm_http'
require 'yaml'
require 'logger'
require 'require_relative'
require_relative 'active_cmis/version'
require_relative 'active_cmis/internal/caching'
require_relative 'active_cmis/internal/connection'
require_relative 'active_cmis/exceptions'
require_relative 'active_cmis/server'
require_relative 'active_cmis/repository'
require_relative 'active_cmis/object'
require_relative 'active_cmis/document'
require_relative 'active_cmis/folder'
require_relative 'active_cmis/policy'
require_relative 'active_cmis/relationship'
require_relative 'active_cmis/type'
require_relative 'active_cmis/atomic_types'
require_relative 'active_cmis/property_definition'
require_relative 'active_cmis/collection.rb'
require_relative 'active_cmis/rendition.rb'
require_relative 'active_cmis/acl.rb'
require_relative 'active_cmis/acl_entry.rb'
require_relative 'active_cmis/ns'
require_relative 'active_cmis/active_cmis'
require_relative 'active_cmis/internal/utils'
require_relative 'active_cmis/rel'
require_relative 'active_cmis/attribute_prefix'
require_relative 'active_cmis/query_result'
