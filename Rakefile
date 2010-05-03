require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'

$VERBOSE = nil

spec = Gem::Specification.new do |s|
  s.name = 'logmerge'
  s.version = '1.0.1'
  s.summary = 'Resolves IP addresses and merges Apache access logs.'
  s.authors = [ 'Eric Hodel', 'Klaas Jan Wierenga' ]
  s.email = [ 'eric@robotcoop.com', 'k.j.wierenga@gmail.com' ]
  s.homepage = 'http://github.com/kjwierenga/logmerge'
  s.description = "
    Logmerge contains two utilities logmerge and ip2name.  logmerge merges Apache
    access logs into one log ordered by date.  ip2name performs DNS lookups on
    Apache access logs using multiple threads and Ruby's DNS resolver library to
    speed through log files."

  s.files = File.read('Manifest.txt').split($/)
  s.require_path = 'lib'

  s.executables = %w[ip2name logmerge]
end

desc 'Run tests'
task :default => [ :test ]

Rake::TestTask.new('test') do |t|
  t.libs << 'test'
  t.verbose = true
end

desc 'Update Manifest.txt'
task :update_manifest do
  sh "find . -type f | sed -e 's%./%%' | egrep -v 'svn|swp|~' | egrep -v '^(doc|pkg)/' | sort > Manifest.txt"
end

desc 'Generate RDoc'
Rake::RDocTask.new :rdoc do |rd|
  rd.rdoc_dir = 'doc'
  rd.rdoc_files.add 'lib', 'README', 'LICENSE'
  rd.rdoc_files.exclude '*/resolv.rb' # WTF doesn't this work?
  rd.main = 'README'
  rd.options << '-d' if `which dot` =~ /\/dot/
end

desc 'Generate RDoc for dev.robotcoop.com'
Rake::RDocTask.new :dev_rdoc do |rd|
  rd.rdoc_dir = '../../../www/trunk/dev/html/Tools/logmerge'
  rd.rdoc_files.add 'lib', 'README', 'LICENSE'
  rd.main = 'README'
  rd.options << '-d' if `which dot` =~ /\/dot/
end

desc 'Build Gem'
Rake::GemPackageTask.new spec do |pkg|
  pkg.need_tar = true
end

desc 'Clean up'
task :clean => [ :clobber_rdoc, :clobber_package ]

desc 'Clean up'
task :clobber => [ :clean ]

# vim: syntax=Ruby

