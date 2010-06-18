require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "hydra"
    gem.summary = %Q{Distributed testing toolkit}
    gem.description = %Q{Spread your tests over multiple machines to test your code faster.}
    gem.email = "nick@smartlogicsolutions.com"
    gem.homepage = "http://github.com/ngauthier/hydra"
    gem.authors = ["Nick Gauthier"]
    gem.add_development_dependency "shoulda", "= 2.10.3"
    gem.add_development_dependency "rspec", "= 1.3.0"
    gem.add_development_dependency "cucumber", "= 0.7.2"
    gem.add_development_dependency "therubyracer", "= 0.7.4"
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/**/*_test.rb'
    test.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: gem install rcov"
  end
end

task :test => :check_dependencies

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "hydra #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
  rdoc.options << '--charset=utf-8'
end
