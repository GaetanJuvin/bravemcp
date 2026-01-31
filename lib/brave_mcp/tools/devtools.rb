# lib/brave_mcp/tools/devtools.rb
module BraveMcp
  module Tools
    class GetConsoleLogs < FastMcp::Tool
      description "Get browser console messages"

      arguments do
        optional(:level).filled(:string).description("Filter by level: all, log, warn, error, info, debug")
        optional(:clear).filled(:bool).description("Clear logs after retrieving")
      end

      def call(level: "all", clear: false)
        logs = BraveMcp::Browser.console_logs.dup

        unless level == "all"
          logs = logs.select { |log| log[:level].to_s == level }
        end

        BraveMcp::Browser.clear_console_logs! if clear

        { logs: logs, count: logs.size }
      end
    end

    class ClearConsole < FastMcp::Tool
      description "Clear captured console logs"

      arguments {}

      def call
        BraveMcp::Browser.clear_console_logs!
        { success: true }
      end
    end
  end
end
