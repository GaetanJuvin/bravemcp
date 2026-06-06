# lib/brave_mcp/server.rb
module BraveMcp
  class Server
    def self.run
      server = FastMcp::Server.new(name: "brave-mcp", version: VERSION)

      register_tools(server)

      # Brave is launched/connected lazily on the first tool use
      # (Browser.page), so opening the MCP server never spawns a window
      # or tab on its own.
      $stderr.puts "BraveMCP ready; Brave will be launched on first tool use."

      at_exit do
        Browser.reset!
      rescue StandardError
        # Browser may already be gone -- ignore cleanup errors
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
