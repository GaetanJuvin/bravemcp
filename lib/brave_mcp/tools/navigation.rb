# lib/brave_mcp/tools/navigation.rb
module BraveMcp
  module Tools
    class Navigate < FastMcp::Tool
      description "Navigate to a URL"

      arguments do
        required(:url).filled(:string).description("The URL to navigate to")
      end

      def call(url:)
        BraveMcp::Browser.page.go_to(url)
        { success: true, url: BraveMcp::Browser.page.current_url }
      rescue Ferrum::PendingConnectionsError
        # Page loaded but has lingering connections (extensions, realtime, etc.)
        { success: true, url: BraveMcp::Browser.page.current_url }
      rescue Ferrum::StatusError => e
        { error: "Navigation failed: #{e.message}" }
      end
    end

    class Reload < FastMcp::Tool
      description "Reload the current page"

      arguments do
        optional(:ignore_cache).filled(:bool).description("Bypass cache when reloading")
      end

      def call(ignore_cache: false)
        if ignore_cache
          BraveMcp::Browser.page.execute("location.reload(true)")
        else
          BraveMcp::Browser.page.refresh
        end
        { success: true, url: BraveMcp::Browser.page.current_url }
      rescue Ferrum::PendingConnectionsError
        { success: true, url: BraveMcp::Browser.page.current_url }
      end
    end

    class Back < FastMcp::Tool
      description "Go back in browser history"

      arguments {}

      def call
        BraveMcp::Browser.page.back
        { success: true, url: BraveMcp::Browser.page.current_url }
      rescue Ferrum::PendingConnectionsError
        { success: true, url: BraveMcp::Browser.page.current_url }
      end
    end

    class Forward < FastMcp::Tool
      description "Go forward in browser history"

      arguments {}

      def call
        BraveMcp::Browser.page.forward
        { success: true, url: BraveMcp::Browser.page.current_url }
      rescue Ferrum::PendingConnectionsError
        { success: true, url: BraveMcp::Browser.page.current_url }
      end
    end

    class GetUrl < FastMcp::Tool
      description "Get the current page URL"

      arguments {}

      def call
        { url: BraveMcp::Browser.page.current_url }
      end
    end
  end
end
