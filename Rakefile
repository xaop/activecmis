require 'rubygems'
require 'rake/gempackagetask'

begin
  require 'yard'

  YARD::Rake::YardocTask.new do |t|
    t.files   = ['lib/**/*.rb', '-', 'TODO']   # optional
    t.options = ["--default-return", "::Object", "--query", "!@private", "--hide-void-return"]
  end
rescue LoadError
  puts "Yard, or a dependency, not available. Install it with gem install jeweler"
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "active_cmis"
    gemspec.summary = "A library to interact with CMIS repositories through the AtomPub/REST binding"
    gemspec.description = "A CMIS library implementing both reading and updating capabilities through the AtomPub/REST binding to CMIS."
    gemspec.email = "joeri@xaop.com"
    gemspec.homepage = "http://xaop.com/labs/activecmis/"
    gemspec.authors = ["Joeri Samson"]

    gemspec.add_runtime_dependency 'nokogiri', '>= 1.4.1'
    gemspec.add_runtime_dependency 'yard', '>= 0.5.0'
    gemspec.add_runtime_dependency 'bluecloth'

    gemspec.has_rdoc = 'yard'
    gemspec.extra_rdoc_files = ['TODO']
    gemspec.rdoc_options << "--default-return" << "::Object" << "--query" << "!@private" << "--hide-void-return"

    gemspec.required_ruby_version = '>= 1.8.6'
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end
