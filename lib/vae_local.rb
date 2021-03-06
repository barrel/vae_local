class VaeLocal
  BANNER = "Vae local preview server, version #{VER}"

  def self.fetch_from_vaeplatform(site, req)
    local = ENV['VAEPLATFORM_LOCAL']
    http = Net::HTTP.new("#{site}." + (local ? "vaeplatform.dev" : "vaeplatform.com"), (local ? 80 : 443))
    http.use_ssl = true unless local
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.start { |http|
      http.read_timeout = 120
      http.request(req)
    }
  end

  def self.port_open?(port)
    !system("lsof -i:#{port}", out: '/dev/null')
  end

  def get_svn_credentials(site)
    home = Dir.chdir { Dir.pwd }
    Dir.glob("#{home}/.subversion/auth/svn.simple/*").each do |file|
      params = parse_svn_auth_file(file)
      if params["svn:realmstring"] =~ /<http:\/\/svn(\.|_)#{site}.(vae|verb)site.com/ or params["svn:realmstring"] =~ /<http:\/\/#{site}(\.|_)svn.(vae|verb)site.com/
        return params
      end
    end
    {}
  end

  def parse_svn_auth_file(file)
    key = nil
    mode = nil
    params = {}
    File.read(file).each_line do |line|
      line.strip!
      if mode == :key
        key = line
        mode = nil
      elsif mode == :value
        params[key] = line
        mode = nil
      else
        if line[0,1] == "K"
          mode = :key
        elsif line[0, 1] == "V"
          mode = :value
        end
      end
    end
    params
  end

  def run
    options = { port: 9999, server: ProxyServer, log_level: "warning" }
    loop {
      break if VaeLocal.port_open?(options[:port])
      options[:port] = options[:port] - 1
    }

    ARGV.options  do |opts|
      opts.banner = BANNER + "\n\nUsage: vae [options]\n         starts a local development server\n       vae [options] deploy\n         promotes the source in Git/Subversion repository to the FTP\n\n  If you are using the Vae Production environment features:\n       vae [options] stage\n         promotes the source in Git/Subversion repository to the staging environment\n       vae [options] stagerelease\n         promotes the source in Git/Subversion repository to the staging environment\n         and releases it to the production environment\n       vae [options] release\n         releases the current staging environment to the production environment\n       vae [options] rollback\n         rolls back the production environment to a previous release\n\nAvailable Options:"
      opts.on("-u","--username <username>","Your Vae username") { |o| options[:username] = o }
      opts.on("-p","--port <port number>","Start server on this port") { |o| options[:port] = o.to_i; raise VaeError "Port #{o.to_i} is already in use." unless VaeLocal.port_open?(o.to_i) }
      opts.on("-r","--root <path to site root>","Path to the root of the local copy of your Vae site.") { |o| options[:site_root] = o }
      opts.on("-s","--site <subdomain>","Vae subdomain for this site") { |o| options[:site] = o }
      opts.on("-f","--full-stack [php|hhvm]","Run in Full Stack Mode.  Optionally provide 'php' or 'hhvm' to specify your preferred PHP runtime") { |o| options[:server] = FullStack; options[:php_runtime] = o }
      opts.on("-b","--branch","If running stage or stagerelease, override the branch to deploy here") { |o| options[:branch] = o }
      opts.on("-d","--data-path <path>","Where to Store Content and Image Data When In Full Stack Mode") { |o| options[:data_path] = o }
      opts.on("-l","--log-level <level>","Vaedb Log Level (for Full Stack Mode)") { |o| options[:log_level] = o }
      opts.on_tail("-h","--help", "Show this help message") { puts opts; exit }
      opts.parse!
    end

    options[:site_root] = Dir.pwd if options[:site_root].nil? and (File.exists?("#{Dir.pwd}/__vae.yml") or File.exists?("#{Dir.pwd}/__verb.yml"))
    if options[:site_root]
      [ "verb", "vae" ].each do |name|
        if File.exists?("#{options[:site_root]}/__#{name}.yml")
          site_conf_file = File.read("#{options[:site_root]}/__#{name}.yml")
          site_conf = YAML.load(site_conf_file)
          options[:site] = site_conf[name]["site"] if site_conf[name] and site_conf[name]["site"]
        end
      end
    end

    raise VaeError, "We could not determine the Vae subdomain for this site.  Please specify it manually by using the --site option or create a __vae.yml file within the site root." if options[:site].nil?

    unless options[:username]
      svn_credentials = get_svn_credentials(options[:site])
      options[:username] = svn_credentials["username"]
      options[:password] = svn_credentials["password"]
    end
    raise VaeError, "We could not determine the Vae username that you use.  Please specify it manually by using the --username option." if options[:username].nil?
    if options[:password].nil?
      options[:password] = ask("Please enter the Vae password for username #{options[:username]}:") { |q| q.echo = false }
    end

    if [ "deploy", "release", "rollback", "stage", "stagerelease" ].include?(ARGV.last)
      stagerelease(ARGV.last, options[:site], options[:username], options[:password], options[:branch])
      exit
    end

    raise VaeError, "You did not specify the path to the root of the local copy of your Vae site.  Please specify it manually by using the --root option or cd to the site root (and make sure it contains a __vae.yml file)." unless options[:site_root]
    raise VaeError, "You specified an invalid path to the local copy of your Vae site." unless File.exists?(options[:site_root])

    Dir.chdir File.dirname(__FILE__)
    puts BANNER

    site = Site.new(subdomain: options[:site], root: options[:site_root], username: options[:username], password: options[:password])
    options[:server].new(site, options).run
    puts "Thanks for using Vae!"
  end

  def show_job_status(res, site)
    data = JSON.parse(res.body)
    if data['error']
      raise VaeError, data['error']
    else
      puts "Request started, waiting for completion..."
      loop do
        sleep 5
        req = Net::HTTP::Get.new("/api/local/v1/job_status/#{data['job']}")
        res = VaeLocal.fetch_from_vaeplatform(site, req)
        status = JSON.parse(res.body)
        if status['status'] == "completed"
          puts data['success']
          return
        elsif status['status'] != "working"
          raise VaeError, "Got the following error from Vae Platform: #{status['message']}"
        end
      end
    end
  rescue JSON::ParserError
    raise VaeError, "An unknown error occurred requesting this operation from Vae Platform.  Please email support for help."
  end

  def stagerelease(action, site, username, password, branch)
    if action == "deploy"
      action = "stage"
    elsif action == "stagerelease"
      stagerelease("stage", site, username, password, branch)
      stagerelease("release", site, username, password, branch)
      return
    end
    req = Net::HTTP::Post.new("/api/local/v1/#{action}")
    req.body = "username=#{CGI::escape(username)}&password=#{CGI::escape(password)}&branch=#{CGI::escape(branch)}&vae_local=1"
    res = VaeLocal.fetch_from_vaeplatform(site, req)
    if res.is_a?(Net::HTTPFound)
      raise VaeError, "Invalid username/password or insufficient permissions."
    else
      show_job_status(res, site)
    end
  end

  def self.run_trapping_exceptions
    begin
      new.run
    rescue VaeError => e
      cmd = $0
      cmd = "vae" if cmd =~ /\.\.\/vae_local/
      puts "** Error:"
      puts "   " + e.to_s
      puts "Type #{cmd} --help for help."
    end
  end
end
