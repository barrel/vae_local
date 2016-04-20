class FullStack
  attr_reader :options

  def initialize(site, options)
    @site = site
    @options = options
    @stop = false
    @pids = []
  end

  def run
    @pids << fork {
      Dir.chdir("#{vae_remote_path}/tests/dependencies/vae_thrift/rb/")
      STDOUT.reopen("/dev/null", "w")
      STDERR.reopen("/dev/null", "w")
      exec "bundle exec ./vaerubyd.rb"
    }
    @pids << fork {
      Dir.chdir("#{vae_remote_path}/tests/dependencies/vae_thrift/cpp/")
      exec "./vaedb"
    }
    @pids << fork {
      Dir.chdir(@site.root)
      exec "php -c #{vae_remote_path}/tests/dependencies/php.ini -S 0.0.0.0:#{options[:port]} #{vae_remote_path}/lib/index.php"
    }
    trap("INT") { @stop = true }
    loop { break if @stop; sleep 0.5 }
    puts "Quit signal received, cleaning up ..."
    @pids.map { |pid| Process.kill("TERM", pid) }
  end

  def vae_remote_path
    thisdir = File.dirname(__FILE__)
    [ "#{thisdir}/../../vae_remote", "#{thisdir}/../../../vae_remote", "/usr/local/vae_remote", "~/vae_remote" ].each { |path|
      return path if File.exists?(path)
    }
    raise VaeError, "Could not find Vae Remote on your system.  Please symlink it to /usr/local/vae_remote or ~/vae_remote"
  end
end
