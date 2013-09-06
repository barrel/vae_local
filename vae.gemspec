Gem::Specification.new do |s|
  s.name = "vae"
  s.version = '0.6.0'
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=

  s.authors = ["Action Verb, LLC", "Kevin Bombino"]
  s.description = "This gem allows for local development for sites on Vae Platform (http://vaeplatform.com/)"
  s.email = "support@actionverb.com"
  s.files = Dir.glob("{bin,lib,test}/**/*")
  s.homepage = "http://vaeplatform.com/vae_local"
  s.rubygems_version = '1.8.10'
  s.summary = "This gem allows for local development for sites on Vae Platform (http://vaeplatform.com/)"

  s.add_dependency 'av-redis-client', '0.2.2'
  s.add_dependency 'chunky_png'
  s.add_dependency 'compass', '0.11.5'
  s.add_dependency 'directory_watcher'
  s.add_dependency 'haml', '3.1.2'
  s.add_dependency 'highline'
  s.add_dependency 'mongrel', '1.2.0.pre2'
  s.add_dependency 'sass', '3.1.4'
end
