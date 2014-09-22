require 'rdoc/task'
require 'rubygems/package_task'
require 'rake/testtask'
require 'rake/clean'
require 'rubygems'

# Specifies the default task to execute. This is often the "test" task
# and we'll change things around as soon as we have some tests.
task  :default => [:rdoc]

# The directory to generate +rdoc+ in.
RDOC_DIR = "doc/html"

# This global variable contains files that will be erased by the `clean` task.
# The `clean` task itself is automatically generated by requiring `rake/clean`.
CLEAN << RDOC_DIR


# This is the task that generates the +rdoc+ documentation from the
# source files. Instantiating Rake::RDocTask automatically generates a
# task called `rdoc`.
Rake::RDocTask.new("rdoc") do |rdoc|
    rdoc.main = "README"
    rdoc.rdoc_files.include(
        "README", "LICENSE", "RUBY_IN_LUA", "LUA_IN_RUBY",
        "rubyluabridge.cpp", "tests/*.rb" )
    rdoc.rdoc_dir = RDOC_DIR
    
    rdoc.title = "RubyLuaBridge: A seamless bridge between Ruby and Lua."
    
    rdoc.options = ["--line-numbers"]
    rdoc.template = 'doc/jamis.rb'

    # Check:
    # `rdoc --help` for more rdoc options
    # the {rdoc documenation home}[http://www.ruby-doc.org/stdlib/libdoc/rdoc/rdoc/index.html]
    # or the documentation for the +Rake::RDocTask+ task[http://rake.rubyforge.org/classes/Rake/RDocTask.html]
end


# The GemPackageTask facilitates getting all your files collected
# together into gem archives. You can also use it to generate tarball
# and zip archives.
PROJECT_NAME    = "rubyluabridge"
PKG_VERSION     = "0.8.0" #Lua::BRIDGE_VERSION
PKG_FILES       = FileList['[A-Z]*', 'test/**/*'].to_a

spec = Gem::Specification.new do |s|
    s.platform = Gem::Platform::RUBY
    s.summary  = "RubyLuaBridge: A seamless bridge between Ruby and Lua."
    s.name     = PROJECT_NAME
    s.version  = PKG_VERSION
    s.files    = PKG_FILES
    s.requirements << "none"
    s.require_path = ''
    s.description = <<END_DESC
RubyLuaBridge lets you access Lua from Ruby.  Eventually, support for accessing Ruby from Lua will be added.
END_DESC
end

# Adding a new GemPackageTask adds a task named `package`, which generates
# packages as gems, tarball and zip archives.
Gem::PackageTask.new(spec) do |pkg|
        pkg.need_zip = true
        pkg.need_tar_gz = true
end


# This task will run the unit tests provided in files called
# 'tests/test*.rb'. The task itself can be run with a call to "rake test"
Rake::TestTask.new do |t|
    #t.libs << "test"
    #t.libs << "lib"
    t.test_files = FileList['tests/*.rb']
    t.verbose = true
end


desc "Install the jamis RDoc template"
task :install_jamis_template do
  require 'rbconfig'
  dest_dir = File.join(Config::CONFIG['rubylibdir'], "rdoc/generators/template/html")
  fail "Unabled to write to #{dest_dir}" unless File.writable?(dest_dir)
  install "doc/jamis.rb", dest_dir, :verbose => true
end
