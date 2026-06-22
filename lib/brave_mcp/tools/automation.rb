# lib/brave_mcp/tools/automation.rb
module BraveMcp
  module Tools
    class Click < FastMcp::Tool
      description "Click on an element"

      arguments do
        required(:selector).filled(:string).description("CSS selector of the element to click")
      end

      def call(selector:)
        page = BraveMcp::Browser.page
        element = resolve_element(page, selector)
        return { error: "Element not found: #{selector}" } unless element

        element.click
        { success: true }
      rescue Ferrum::BrowserError, Ferrum::NodeNotFoundError => e
        { error: "Element not interactable (#{selector}): #{e.message}" }
      rescue Ferrum::TimeoutError
        { error: "Timed out interacting with element (#{selector}). The page may be loading slowly — try again." }
      end

      private

      def resolve_element(page, selector)
        if (match = selector.match(/^(.+):has-text\(["'](.+?)["']\)$/))
          tag, text = match[1], match[2]
          find_by_text(page, tag, text)
        elsif selector.start_with?("text=")
          text = selector.sub("text=", "").gsub(/^["']|["']$/, "")
          find_by_text(page, "*", text)
        else
          page.at_css(selector)
        end
      end

      def find_by_text(page, tag, text)
        escaped = text.gsub("\\", "\\\\\\\\").gsub("'", "\\\\'")
        js = <<~JS
          (() => {
            const els = document.querySelectorAll('#{tag}');
            for (const el of els) {
              if (el.textContent.trim().includes('#{escaped}')) return el;
            }
            return null;
          })()
        JS
        node = page.evaluate(js)
        node
      end
    end

    class Type < FastMcp::Tool
      description "Type text into the currently focused element"

      arguments do
        required(:text).filled(:string).description("Text to type")
      end

      def call(text:)
        page = BraveMcp::Browser.page

        # Select all existing text and delete it first
        page.keyboard.press("Meta+a")
        page.keyboard.press("Backspace")

        page.keyboard.type(text)
        { success: true }
      end
    end

    class Fill < FastMcp::Tool
      description "Fill an input field with text (React-compatible)"

      arguments do
        required(:selector).filled(:string).description("CSS selector of the input field")
        required(:value).filled(:string).description("Value to fill in")
      end

      def call(selector:, value:)
        page = BraveMcp::Browser.page
        element = page.at_css(selector)
        return { error: "Element not found: #{selector}" } unless element

        element.focus

        escaped = value.gsub("\\", "\\\\\\\\").gsub("'", "\\\\'")

        # Use the native value setter to bypass React's synthetic event system,
        # then dispatch input+change events so React picks up the new value.
        element.evaluate(<<~JS)
          (() => {
            const nativeSetter = Object.getOwnPropertyDescriptor(
              window.HTMLInputElement.prototype, 'value'
            )?.set || Object.getOwnPropertyDescriptor(
              window.HTMLTextAreaElement.prototype, 'value'
            )?.set;
            if (nativeSetter) {
              nativeSetter.call(this, '#{escaped}');
            } else {
              this.value = '#{escaped}';
            }
            this.dispatchEvent(new Event('input', { bubbles: true }));
            this.dispatchEvent(new Event('change', { bubbles: true }));
          })()
        JS

        { success: true }
      rescue Ferrum::BrowserError, Ferrum::NodeNotFoundError => e
        { error: "Element not interactable (#{selector}): #{e.message}" }
      rescue Ferrum::TimeoutError
        { error: "Timed out interacting with element (#{selector}). The page may be loading slowly — try again." }
      end
    end

    class Select < FastMcp::Tool
      description "Select an option from a dropdown"

      arguments do
        required(:selector).filled(:string).description("CSS selector of the select element")
        optional(:value).filled(:string).description("Option value to select")
        optional(:text).filled(:string).description("Option text to select")
      end

      def call(selector:, value: nil, text: nil)
        page = BraveMcp::Browser.page
        element = page.at_css(selector)
        return { error: "Element not found: #{selector}" } unless element

        if value
          element.select(value: value)
        elsif text
          element.select(text: text)
        else
          return { error: "Must provide either value or text" }
        end

        { success: true }
      rescue Ferrum::BrowserError, Ferrum::NodeNotFoundError => e
        { error: "Element not interactable (#{selector}): #{e.message}" }
      rescue Ferrum::TimeoutError
        { error: "Timed out interacting with element (#{selector}). The page may be loading slowly — try again." }
      end
    end

    class Hover < FastMcp::Tool
      description "Hover over an element"

      arguments do
        required(:selector).filled(:string).description("CSS selector of the element to hover")
      end

      def call(selector:)
        page = BraveMcp::Browser.page
        element = page.at_css(selector)
        return { error: "Element not found: #{selector}" } unless element

        # Scroll element into view first
        element.scroll_into_view

        # Get element's bounding box via JavaScript
        box = element.evaluate("JSON.stringify(this.getBoundingClientRect())")
        box = JSON.parse(box)

        # Calculate center of the element
        x = box["x"] + box["width"] / 2.0
        y = box["y"] + box["height"] / 2.0

        # Move mouse to center of element
        page.mouse.move(x: x, y: y)

        { success: true }
      rescue Ferrum::BrowserError, Ferrum::NodeNotFoundError => e
        { error: "Element not interactable (#{selector}): #{e.message}" }
      rescue Ferrum::TimeoutError
        { error: "Timed out interacting with element (#{selector}). The page may be loading slowly — try again." }
      end
    end

    class Scroll < FastMcp::Tool
      description "Scroll the page or scroll an element into view"

      arguments do
        optional(:selector).filled(:string).description("CSS selector to scroll into view")
        optional(:x).filled(:integer).description("Horizontal scroll amount in pixels")
        optional(:y).filled(:integer).description("Vertical scroll amount in pixels")
      end

      # Probes multiple viewport points to find the largest scrollable
      # container, handling pages with nested overflow areas, fixed
      # headers, or overlay elements that cover the viewport center.
      FIND_SCROLL_TARGET_JS = <<~JS
        (function() {
          var vw = window.innerWidth;
          var vh = window.innerHeight;

          var probes = [
            [vw / 2, vh / 2],
            [vw / 2, vh * 0.65],
            [vw / 2, vh * 0.35],
            [vw * 0.25, vh / 2],
            [vw * 0.75, vh / 2]
          ];

          var best = null;
          var bestArea = 0;
          var seen = [];

          function alreadySeen(el) {
            for (var i = 0; i < seen.length; i++) {
              if (seen[i] === el) return true;
            }
            return false;
          }

          function findScrollableAt(x, y) {
            var el = document.elementFromPoint(x, y);
            while (el && el !== document.documentElement && el !== document.body) {
              var style = window.getComputedStyle(el);
              var oy = style.overflowY;
              if ((oy === 'auto' || oy === 'scroll') && el.scrollHeight > el.clientHeight) {
                return el;
              }
              el = el.parentElement;
            }
            return null;
          }

          for (var i = 0; i < probes.length; i++) {
            var el = findScrollableAt(probes[i][0], probes[i][1]);
            if (el && !alreadySeen(el)) {
              seen.push(el);
              var rect = el.getBoundingClientRect();
              var area = rect.width * rect.height;
              if (area > bestArea) {
                bestArea = area;
                best = rect;
              }
            }
          }

          if (best) {
            return {
              x: Math.max(0, Math.min(vw - 1, best.x + best.width / 2)),
              y: Math.max(0, Math.min(vh - 1, best.y + best.height / 2))
            };
          }

          return { x: vw / 2, y: vh / 2 };
        })()
      JS

      def call(selector: nil, x: nil, y: nil)
        page = BraveMcp::Browser.page

        if selector
          element = page.at_css(selector)
          return { error: "Element not found: #{selector}" } unless element
          element.scroll_into_view
        elsif x || y
          # Find the best scroll target by detecting scrollable containers
          # (overflow: auto/scroll) rather than always dispatching at the
          # viewport center, which misses nested scroll areas.
          # Fall back to viewport center constants if JS evaluation times out.
          begin
            target = page.evaluate(FIND_SCROLL_TARGET_JS)
            target_x = target["x"].to_i
            target_y = target["y"].to_i
          rescue Ferrum::TimeoutError
            target_x = BraveMcp::Browser::DEFAULT_VIEWPORT_WIDTH / 2
            target_y = BraveMcp::Browser::DEFAULT_VIEWPORT_HEIGHT / 2
          end

          begin
            # Use CDP mouse wheel events instead of window.scrollBy so the
            # browser treats it as real user input.  This forces the compositor
            # to repaint (even for background tabs) and triggers lazy-loading
            # observers that ignore programmatic scrolls.
            page.command("Input.dispatchMouseEvent",
              type: "mouseWheel",
              x: target_x,
              y: target_y,
              deltaX: x || 0,
              deltaY: y || 0
            )
          rescue Ferrum::TimeoutError
            # Fallback: use programmatic scroll via CDP Runtime.evaluate.
            # Less ideal (won't trigger IntersectionObserver-based lazy
            # loading) but more reliable on heavy pages.
            page.command("Runtime.evaluate",
              expression: "window.scrollBy(#{x || 0}, #{y || 0})",
              awaitPromise: false
            )
          end
          # Give the browser a moment to composite the new frame
          sleep 0.3
        else
          return { error: "Must provide selector or x/y coordinates" }
        end

        { success: true }
      rescue Ferrum::BrowserError, Ferrum::NodeNotFoundError => e
        { error: "Element not interactable (#{selector}): #{e.message}" }
      rescue Ferrum::TimeoutError
        { error: "Timed out interacting with element (#{selector}). The page may be loading slowly — try again." }
      end
    end

    class Focus < FastMcp::Tool
      description "Focus on an element"

      arguments do
        required(:selector).filled(:string).description("CSS selector of the element to focus")
      end

      def call(selector:)
        page = BraveMcp::Browser.page
        element = page.at_css(selector)
        return { error: "Element not found: #{selector}" } unless element

        element.focus
        { success: true }
      rescue Ferrum::BrowserError, Ferrum::NodeNotFoundError => e
        { error: "Element not interactable (#{selector}): #{e.message}" }
      rescue Ferrum::TimeoutError
        { error: "Timed out interacting with element (#{selector}). The page may be loading slowly — try again." }
      end
    end
  end
end
