class Site
  attr_reader :password, :root, :session_id, :subdomain, :username, :data_path
  attr_accessor :secret_key

  def initialize(options)
    @root = options[:root] if options[:root]
    @subdomain = options[:subdomain] if options[:subdomain]
    @username = options[:username] if options[:username]
    @password = options[:password] if options[:password]
    @session_id = Digest::MD5.hexdigest(rand.to_s)
    @data_path = options[:data_path] || "#{@root}/.vae/data/"
    login_to_server
  end

  def fetch_from_server(req)
    http = Net::HTTP.new("#{subdomain}.vaesite.com")
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.start { |http|
      http.read_timeout = 120
      http.request(req)
    }
  end

  def login_to_server
    req = Net::HTTP::Post.new("/")
    req.body = "__vae_local=#{session_id}&__local_username=#{CGI.escape(username)}&__local_password=#{CGI.escape(password)}&__local_version=#{VER}"
    res = fetch_from_server(req)
    if res.body == "BAD"
      raise VaeError, "Invalid password or insufficient permissions."
    elsif res.body =~ /MSG/
      puts res.body.gsub(/MSG/, "")
    elsif res.body != "GOOD"
      raise VaeError, "Could not connect to Vae servers.  Please check your Internet connection."
    end
  end
end
