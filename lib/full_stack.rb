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
      if !File.exists?(@site.data_path + "/assets/")
        FileUtils.ln_s("#{vae_remote_path}/public", @site.data_path + "/assets")
      end
      @site.secret_key = data['secret_key']
      generation = File.exists?("#{@site.data_path}feed_generation") ? File.open("#{@site.data_path}feed_generation").read.to_i : 0
      if data['feed_url'] and data['feed_generation'].to_i > generation
        puts "Downloading updated Site Data Feed..."
        if curl = File.which("curl")
          `curl -o #{Shellwords.shellescape(@site.data_path)}feed.xml #{Shellwords.shellescape(data['feed_url'])}`
        else
          download_feed(data['feed_url'])
        end
        File.open("#{@site.data_path}feed_generation",'w') { |f| f.write(data['feed_generation']) }
      end
      File.open("#{@site.data_path}settings.php",'w') { |f| f.write(data['settings']) }
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
      File.open("#{@site.data_path}feed.xml", 'w') { |f|
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

  def launch_daemons
    if VaeLocal.port_open?(9090)
      @pids << fork {
        Dir.chdir("#{vae_thrift_path}/rb/")
        STDOUT.reopen("/dev/null", "w")
        STDERR.reopen("/dev/null", "w")
        exec "bundle exec ./vaerubyd.rb"
      }
    end
    port = 9091
    serve_root = @site.root
    loop {
      break if VaeLocal.port_open?(port)
      port = port + 1
    }
    if File.exists?(@site.root + "/.jekyll")
      serve_root = @site.root + "/_site/"
      FileUtils.mkdir_p(serve_root)
      @pids << fork {
        exec "bundle exec jekyll build --watch --source #{Shellwords.shellescape(@site.root)} --destination #{Shellwords.shellescape(serve_root)}"
      }
    end
    @pids << fork {
      Dir.chdir("#{vae_thrift_path}/cpp/")
      ENV['VAE_LOCAL_VAEDB_PORT'] = port.to_s
      exec "./vaedb --port #{port} --busaddress 'tcp://*:#{port-4000}' --test --log_level #{options[:log_level]}"
    }
    @pids << fork {
      Dir.chdir(serve_root)
      ENV['VAE_LOCAL_BACKSTAGE'] = @site.subdomain + ".vaeplatform." + (ENV['VAEPLATFORM_LOCAL'] ? "dev" : "com")
      ENV['VAE_LOCAL_SECRET_KEY'] = @site.secret_key
      ENV['VAE_LOCAL_DATA_PATH'] = @site.data_path
      exec "php -c #{vae_remote_path}/tests/dependencies/php.ini -S 0.0.0.0:#{options[:port]} #{vae_remote_path}/lib/index.php"
    }
  end

  def vae_remote_path
    return @vae_remote_path if @vae_remote_path
    thisdir = File.dirname(__FILE__)
    [ "#{thisdir}/../../vae_remote", "#{thisdir}/../../../vae_remote", "/usr/local/vae_remote", "/usr/local/opt/vae-thrift", "/usr/local/Cellar/vae_thrift/1.0.0", "~/vae_remote" ].each { |path|
      if File.exists?(path)
        return @vae_remote_path = path
      end
    }
    raise VaeError, "Could not find Vae Remote on your system.#{brew_message}"
  end

  def vae_thrift_path
    return @vae_thrift_path if @vae_thrift_path
    thisdir = File.dirname(__FILE__)
    [ "#{thisdir}/../../vae_thrift", "#{thisdir}/../../../vae_thrift", "/usr/local/vae_thrift", "/usr/local/opt/vae-thrift", "/usr/local/Cellar/vae_thrift/1.0.0", "~/vae_thrift", "#{vae_remote_path}/tests/dependencies/vae_thrift" ].each { |path|
      if File.exists?(path)
        return @vae_remote_path = path
      end
    }
    raise VaeError, "Could not find Vae Thrift on your system.#{brew_message}"
  end

  def brew_message
    "\n\nTo install Vae Local Full Stack dependencies on macOS via Homebrew, run the following commands:\n  brew tap actionverb/tap\n  brew install vae-remote vae-thrift vaeql\n\nMake sure you resolve any errors from Homebrew before proceeding."
  end
end
