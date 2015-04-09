# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-
# stub: active_cmis 0.3.6 ruby lib

Gem::Specification.new do |s|
  s.name = "active_cmis"
  s.version = "0.3.6"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Joeri Samson"]
  s.date = "2015-04-09"
  s.description = "A CMIS library implementing both reading and updating capabilities through the AtomPub/REST binding to CMIS."
  s.email = "joeri@xaop.com"
  s.extra_rdoc_files = [
    "LICENSE",
    "README.md",
    "TODO"
  ]
  s.files = [
    "AUTHORS",
    "LICENSE",
    "README.md",
    "Rakefile",
    "TODO",
    "VERSION.yml",
    "active_cmis.gemspec",
    "lib/active_cmis.rb",
    "lib/active_cmis/acl.rb",
    "lib/active_cmis/acl_entry.rb",
    "lib/active_cmis/active_cmis.rb",
    "lib/active_cmis/atomic_types.rb",
    "lib/active_cmis/attribute_prefix.rb",
    "lib/active_cmis/collection.rb",
    "lib/active_cmis/document.rb",
    "lib/active_cmis/exceptions.rb",
    "lib/active_cmis/folder.rb",
    "lib/active_cmis/internal/caching.rb",
    "lib/active_cmis/internal/connection.rb",
    "lib/active_cmis/internal/utils.rb",
    "lib/active_cmis/ns.rb",
    "lib/active_cmis/object.rb",
    "lib/active_cmis/policy.rb",
    "lib/active_cmis/property_definition.rb",
    "lib/active_cmis/query_result.rb",
    "lib/active_cmis/rel.rb",
    "lib/active_cmis/relationship.rb",
    "lib/active_cmis/rendition.rb",
    "lib/active_cmis/repository.rb",
    "lib/active_cmis/server.rb",
    "lib/active_cmis/type.rb",
    "lib/active_cmis/version.rb"
  ]
  s.homepage = "http://xaop.com/labs/activecmis/"
  s.required_ruby_version = Gem::Requirement.new(">= 1.8.6")
  s.rubygems_version = "2.4.5"
  s.summary = "A library to interact with CMIS repositories through the AtomPub/REST binding"

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<nokogiri>, [">= 1.4.1"])
      s.add_runtime_dependency(%q<ntlm-http>, [">= 0.1.1", "~> 0.1"])
      s.add_runtime_dependency(%q<require_relative>, [">= 1.0.2", "~> 1.0"])
    else
      s.add_dependency(%q<nokogiri>, [">= 1.4.1"])
      s.add_dependency(%q<ntlm-http>, [">= 0.1.1", "~> 0.1"])
      s.add_dependency(%q<require_relative>, [">= 1.0.2", "~> 1.0"])
    end
  else
    s.add_dependency(%q<nokogiri>, [">= 1.4.1"])
    s.add_dependency(%q<ntlm-http>, [">= 0.1.1", "~> 0.1"])
    s.add_dependency(%q<require_relative>, [">= 1.0.2", "~> 1.0"])
  end
end

