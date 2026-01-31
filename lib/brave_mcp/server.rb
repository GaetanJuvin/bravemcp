# lib/brave_mcp/server.rb
module BraveMcp
  class Server
    def self.run
      server = FastMcp::Server.new(name: "brave-mcp", version: VERSION)

      register_tools(server)

      # Attempt connection on startup to fail fast with helpful message
      begin
        Browser.instance
        $stderr.puts "BraveMCP connected to Brave browser"
      rescue Browser::ConnectionError => e
        $stderr.puts "Warning: #{e.message}"
        $stderr.puts "Tools will attempt to connect on first use."
      end

      server.start
    end

    def self.register_tools(server)
      Dir[File.join(__dir__, "tools", "*.rb")].sort.each { |f| require f }

      Tools.constants.each do |const|
        tool_class = Tools.const_get(const)
        server.register_tool(tool_class) if tool_class < FastMcp::Tool
      end
    end
  end
end
