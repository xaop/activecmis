require 'rubygems'
require 'rake/gempackagetask'
require 'yard'

YARD::Rake::YardocTask.new do |t|
  t.files   = ['lib/**/*.rb']   # optional
  t.options = ["--default-return", "::Object", "--query", "!@private", "--hide-void-return"]
end

PACKAGE_VERSION = File.readlines("VERSION")[0][/[\d.]*/]

desc "Build the gem"
spec = Gem::Specification.new do |s|
  s.name = "active_cmis"
  s.version = PACKAGE_VERSION
  s.author = "Joeri Samson"
  s.email = "joeri@xaop.com"

  s.summary = "Interface to CMIS implementations comparable to ActiveRecord"
  s.description = "An interface to CMIS, using the AtomPub Rest interface"

  s.files += %w(VERSION Rakefile)
  s.files += Dir['lib/**/*.rb']

  s.add_runtime_dependency 'nokogiri', '>= 1.4.1'

  s.rdoc_options << "--accessor" << "cache=cached"

  s.required_ruby_version = '>= 1.8.6'
  s.platform = Gem::Platform::RUBY
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end
