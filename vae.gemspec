Gem::Specification.new do |s|
  version = File.open(File.dirname(__FILE__) + "/lib/version.rb") { |f| f.read }.match(/"(.*)"/)[0].gsub('"', "")

  s.name = "vae"
  s.version = version
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=

  s.authors = ["Action Verb, LLC", "Kevin Bombino"]
  s.bindir = "bin"
  s.description = "Supports local development for Vae Platform (http://vaeplatform.com/)"
  s.email = "support@actionverb.com"
  s.executables << "vae"
  s.files = Dir.glob("{bin,lib,test}/**/*")
  s.homepage = "http://docs.vaeplatform.com/vae_local"
  s.license = "GPL"
  s.rubygems_version = '1.8.10'
  s.summary = "This gem allows for local development for sites on Vae Platform (http://vaeplatform.com/)"

  s.add_dependency 'chunky_png'
  s.add_dependency 'compass'
  s.add_dependency 'directory_watcher'
  s.add_dependency 'haml'
  s.add_dependency 'highline'
  s.add_dependency 'json'
  s.add_dependency 'mongrel', '1.2.0.pre2'
  s.add_dependency 'sass'
end
