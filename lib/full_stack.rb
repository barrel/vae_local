class FullStack
  attr_reader :options

  def initialize(site, options)
    @site = site
    @options = options
    @stop = false
    @pids = []
  end

  def authenticate
    req = Net::HTTP::Post.new("/api/local/v1/authorize")
    req.body = "username=#{CGI.escape(@site.username)}&password=#{CGI.escape(@site.password)}"
    res = VaeLocal.fetch_from_vaeplatform(@site.subdomain, req)
    data = JSON.parse(res.body)
    if data['valid'] == "valid"
      FileUtils.mkdir_p(@site.data_path)
      @site.secret_key = data['secret_key']
      generation = File.exists?("#{@site.data_path}/feed_generation") ? File.open("#{@site.data_path}/feed_generation").read.to_i : 0
      if data['feed_url'] and data['feed_generation'].to_i > generation
        puts "Downloading updated Site Data Feed..."
        if curl = File.which("curl")
          `curl -o #{Shellwords.shellescape(@site.data_path)}/feed.xml #{Shellwords.shellescape(data['feed_url'])}`
        else
          download_feed(data['feed_url'])
        end
        File.open("#{@site.data_path}/feed_generation",'w') { |f| f.write(data['feed_generation']) }
      end
      File.open("#{@site.data_path}/settings.php",'w') { |f| f.write(data['settings']) }
    else
      raise VaeError, "Error Connecting to Vae with the supplied Username and Password.  Please make sure this user has Vae Local permissions assigned."
    end
  rescue JSON::ParserError
    raise VaeError, "An unknown error occurred signing into Vae Platform.  Please email support for help."
  end

  def download_feed(url)
    url_base = url.split('/')[2]
    url_path = '/'+url.split('/')[3..-1].join('/')
    Net::HTTP.start(url_base) { |http|
      File.open("#{@site.data_path}/feed.xml", 'w') { |f|
        http.get(URI.escape(url_path)) { |str|
          f.write str
        }
      }
    }
  end

  def run
    authenticate
    launch_daemons
    trap("INT") { @stop = true }
    loop { break if @stop; sleep 0.5 }
    puts "Quit signal received, cleaning up ..."
    @pids.map { |pid| Process.kill("TERM", pid) }
  end

  def port_open?(port)
    system("lsof -i:#{port}", out: '/dev/null')
  end

  def launch_daemons
    puts "Launching Daemons"
    if !port_open?(9090)
      puts "Starting Vaerubyd..."
      @pids << fork {
        Dir.chdir("#{vae_remote_path}/tests/dependencies/vae_thrift/rb/")
        STDOUT.reopen("/dev/null", "w")
        STDERR.reopen("/dev/null", "w")
        exec "bundle exec ./vaerubyd.rb"
      }
    end
    port = 9091
    loop {
      break if !port_open?(port)
      port = port + 1
    }
    @pids << fork {
      puts "Starting Vaedb on port #{port}..."
      Dir.chdir("#{vae_remote_path}/tests/dependencies/vae_thrift/cpp/")
      ENV['VAE_LOCAL_VAEDB_PORT'] = port.to_s
      exec "./vaedb --port #{port} --test --log_level warning"
    }
    @pids << fork {
      Dir.chdir(@site.root)
      ENV['VAE_LOCAL_SUBDOMAIN'] = @site.subdomain
      ENV['VAE_LOCAL_SECRET_KEY'] = @site.secret_key
      ENV['VAE_LOCAL_DATA_PATH'] = @site.data_path
      exec "php -c #{vae_remote_path}/tests/dependencies/php.ini -S 0.0.0.0:#{options[:port]} #{vae_remote_path}/lib/index.php"
    }
  end

  def vae_remote_path
    thisdir = File.dirname(__FILE__)
    [ "#{thisdir}/../../vae_remote", "#{thisdir}/../../../vae_remote", "/usr/local/vae_remote", "~/vae_remote" ].each { |path|
      return path if File.exists?(path)
    }
    raise VaeError, "Could not find Vae Remote on your system.  Please symlink it to /usr/local/vae_remote or ~/vae_remote"
  end
end
