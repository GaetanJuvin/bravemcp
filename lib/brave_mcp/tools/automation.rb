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
        element = page.at_css(selector)
        return { error: "Element not found: #{selector}" } unless element

        element.click
        { success: true }
      rescue Ferrum::BrowserError, Ferrum::NodeNotFoundError => e
        { error: "Element not interactable (#{selector}): #{e.message}" }
      rescue Ferrum::TimeoutError
        { error: "Timed out interacting with element (#{selector}). The page may be loading slowly — try again." }
      end
    end

    class Type < FastMcp::Tool
      description "Type text into the currently focused element"

      arguments do
        required(:text).filled(:string).description("Text to type")
      end

      def call(text:)
        page = BraveMcp::Browser.page
        page.keyboard.type(text)
        { success: true }
      end
    end

    class Fill < FastMcp::Tool
      description "Fill an input field with text"

      arguments do
        required(:selector).filled(:string).description("CSS selector of the input field")
        required(:value).filled(:string).description("Value to fill in")
      end

      def call(selector:, value:)
        page = BraveMcp::Browser.page
        element = page.at_css(selector)
        return { error: "Element not found: #{selector}" } unless element

        element.focus.type(value)
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

      def call(selector: nil, x: nil, y: nil)
        page = BraveMcp::Browser.page

        if selector
          element = page.at_css(selector)
          return { error: "Element not found: #{selector}" } unless element
          element.scroll_into_view
        elsif x || y
          page.execute("window.scrollBy(#{x || 0}, #{y || 0})")
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
