class ProxyServer
  def initialize(site, options)
    $site = site
    @options = options

    set_mime_types
  end

  def run
    server = Mongrel::Configurator.new host: "0.0.0.0", port: @options[:port] do
      listener do
        uri "/", handler: VaeSiteServlet.new($site)
      end
      trap("INT") { raise Mongrel::StopServer }
      run
    end

    puts "Vae is in action at http://localhost:#{options[:port]}/"
    puts "  (hit Control+C to exit)"

    begin
      server.join
    rescue Mongrel::StopServer
    end
  end

  def set_mime_types
    WEBrick::HTTPUtils::DefaultMimeTypes.store 'js', 'application/javascript'
    WEBrick::HTTPUtils::DefaultMimeTypes.store 'svg', 'image/svg+xml'
  end
end
