# lib/brave_mcp/tools/javascript.rb
module BraveMcp
  module Tools
    class Evaluate < FastMcp::Tool
      description "Execute JavaScript in the page context and return the result"

      arguments do
        required(:script).filled(:string).description("JavaScript code to execute")
      end

      def call(script:)
        result = BraveMcp::Browser.page.evaluate(script)
        { result: result }
      rescue Ferrum::JavaScriptError => e
        { error: e.message }
      end
    end

    class WaitForSelector < FastMcp::Tool
      description "Wait for an element to appear in the DOM"

      arguments do
        required(:selector).filled(:string).description("CSS selector to wait for")
        optional(:timeout).filled(:integer).description("Timeout in milliseconds (default: 5000)")
      end

      def call(selector:, timeout: 5000)
        page = BraveMcp::Browser.page

        page.at_css(selector, wait: timeout / 1000.0)
        { success: true, found: true }
      rescue Ferrum::NodeNotFoundError
        { success: false, found: false, error: "Element not found within timeout: #{selector}" }
      end
    end

    class WaitForNavigation < FastMcp::Tool
      description "Wait for page navigation to complete"

      arguments do
        optional(:timeout).filled(:integer).description("Timeout in milliseconds (default: 5000)")
      end

      def call(timeout: 5000)
        page = BraveMcp::Browser.page
        # Ferrum handles navigation waiting internally, but we can add a network idle check
        sleep 0.5 # Brief wait for navigation to start
        page.network.wait_for_idle(timeout: timeout / 1000.0)
        { success: true, url: page.current_url }
      rescue Ferrum::TimeoutError
        { success: false, error: "Navigation timeout" }
      end
    end
  end
end
