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

    class GetNetworkRequests < FastMcp::Tool
      description "Get captured network requests"

      arguments do
        optional(:filter).filled(:string).description("Filter by resource type: xhr, fetch, document, script, stylesheet, image, font, other")
      end

      def call(filter: nil)
        traffic = BraveMcp::Browser.page.traffic

        requests = traffic.map do |exchange|
          req = exchange.request
          resp = exchange.response

          {
            id: exchange.id,
            url: req&.url,
            method: req&.method,
            type: exchange.type,
            status: resp&.status,
            size: resp&.body_size
          }
        end

        if filter
          requests = requests.select { |r| r[:type]&.downcase == filter.downcase }
        end

        { requests: requests, count: requests.size }
      end
    end

    class GetRequestDetails < FastMcp::Tool
      description "Get full details of a specific network request"

      arguments do
        required(:request_id).filled(:string).description("Request ID from get_network_requests")
      end

      def call(request_id:)
        traffic = BraveMcp::Browser.page.traffic
        exchange = traffic.find { |ex| ex.id == request_id }

        return { error: "Request not found: #{request_id}" } unless exchange

        req = exchange.request
        resp = exchange.response

        {
          request: {
            url: req&.url,
            method: req&.method,
            headers: req&.headers
          },
          response: {
            status: resp&.status,
            headers: resp&.headers,
            body_preview: resp&.body&.to_s&.slice(0, 1000)
          }
        }
      end
    end

    class ClearNetwork < FastMcp::Tool
      description "Clear captured network logs"

      arguments {}

      def call
        BraveMcp::Browser.page.network.clear(:traffic)
        { success: true }
      end
    end
  end
end
