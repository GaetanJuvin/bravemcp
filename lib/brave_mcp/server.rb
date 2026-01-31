# lib/brave_mcp/server.rb
module BraveMcp
  class Server
    def self.run
      server = FastMcp::Server.new(name: "brave-mcp", version: VERSION)

      # Tools will be registered here
      register_tools(server)

      server.start
    end

    def self.register_tools(server)
      Dir[File.join(__dir__, "tools", "*.rb")].each { |f| require f }

      # Register all tool classes
      Tools.constants.each do |const|
        tool_class = Tools.const_get(const)
        server.register_tool(tool_class) if tool_class < FastMcp::Tool
      end
    end
  end
end
