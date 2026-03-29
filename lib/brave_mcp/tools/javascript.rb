# lib/brave_mcp/tools/javascript.rb
module BraveMcp
  module Tools
    class Evaluate < FastMcp::Tool
      description "Execute JavaScript in the page context and return the result"

      arguments do
        required(:script).filled(:string).description("JavaScript code to execute")
      end

      def call(script:)
        page = BraveMcp::Browser.page

        # Ferrum's evaluate() wraps the script in a function and returns
        # the *completion value* of the last expression.  Multi-statement
        # scripts like "window.scrollTo(0,800); 'done'" work because JS
        # completion semantics return the last expression.  However,
        # statements whose completion value is `undefined` (assignments,
        # void calls) produce nil in Ruby.
        #
        # To give callers the most useful result, try the direct evaluate
        # first.  If it returns nil *and* the script looks like it has
        # multiple statements, re-run via CDP Runtime.evaluate which
        # returns the raw protocol result and handles completion values
        # more faithfully.
        result = page.evaluate(script)

        if result.nil?
          # Try CDP directly — returnByValue gives us primitives, and
          # we check the result subtype to distinguish real nil from void.
          raw = page.command("Runtime.evaluate",
            expression: script,
            returnByValue: true,
            awaitPromise: false
          )
          remote = raw.dig("result")
          if remote && remote["type"] != "undefined"
            result = remote["value"]
          end
        end

        { result: result }
      rescue Ferrum::JavaScriptError, Ferrum::BrowserError => e
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
        timeout_sec = timeout / 1000.0
        interval = 0.1
        elapsed = 0

        loop do
          element = page.at_css(selector)
          return { success: true, found: true } if element

          sleep interval
          elapsed += interval
          if elapsed >= timeout_sec
            return { success: false, found: false, error: "Element not found within timeout: #{selector}" }
          end
        end
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
