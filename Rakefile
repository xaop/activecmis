require 'rubygems'
require 'rake/gempackagetask'

PACKAGE_VERSION = File.readlines("VERSION")[0][/[\d.]*/]

desc "Build the gem"
spec = Gem::Specification.new do |s|
  s.name = "active_cmis"
  s.version = PACKAGE_VERSION
  s.author = "Joeri Samson"
  s.email = "joeri@xaop.com"

  s.summary = "Interface to CMIS implementations comparable to ActiveRecord"
  s.description = s.summary

  s.files += %w(VERSION Rakefile)
  s.files += Dir['lib/**/*.rb']

  s.required_ruby_version = '>= 1.8.1'
  s.platform = Gem::Platform::RUBY
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end
