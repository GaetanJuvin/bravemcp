# lib/brave_mcp/tools/content.rb
require "base64"
require "mini_magick"

module BraveMcp
  module Tools
    class GetHtml < FastMcp::Tool
      description "Get the HTML content of the page or a specific element"

      arguments do
        optional(:selector).filled(:string).description("CSS selector to get HTML for specific element")
      end

      def call(selector: nil)
        page = BraveMcp::Browser.page

        if selector
          element = page.at_css(selector)
          return { error: "Element not found: #{selector}" } unless element
          { html: element.property("outerHTML") }
        else
          { html: page.body }
        end
      rescue Ferrum::BrowserError, Ferrum::NodeNotFoundError => e
        { error: "Element not interactable (#{selector}): #{e.message}" }
      end
    end

    class GetText < FastMcp::Tool
      description "Get the visible text content of the page or a specific element"

      arguments do
        optional(:selector).filled(:string).description("CSS selector to get text for specific element")
      end

      def call(selector: nil)
        page = BraveMcp::Browser.page

        if selector
          element = page.at_css(selector)
          return { error: "Element not found: #{selector}" } unless element
          { text: element.text }
        else
          { text: page.at_css("body").text }
        end
      rescue Ferrum::BrowserError, Ferrum::NodeNotFoundError => e
        { error: "Element not interactable (#{selector}): #{e.message}" }
      end
    end

    class GetTitle < FastMcp::Tool
      description "Get the current page title"

      arguments {}

      def call
        { title: BraveMcp::Browser.page.current_title }
      end
    end

    class Screenshot < FastMcp::Tool
      MAX_DIMENSION = 2000

      description "Take a screenshot of the page or a specific element"

      arguments do
        optional(:selector).filled(:string).description("CSS selector to screenshot specific element")
        optional(:full_page).filled(:bool).description("Capture the full scrollable page")
      end

      def call(selector: nil, full_page: false)
        page = BraveMcp::Browser.page

        # Create screenshots directory
        screenshot_dir = "/tmp/brave_mcp_screenshots"
        Dir.mkdir(screenshot_dir) unless Dir.exist?(screenshot_dir)

        # Generate unique filename with timestamp
        timestamp = Time.now.strftime("%Y%m%d_%H%M%S_%L")
        filename = "screenshot_#{timestamp}.png"
        filepath = File.join(screenshot_dir, filename)

        options = { path: filepath }
        options[:full] = true if full_page
        options[:selector] = selector if selector

        page.screenshot(**options)

        # Resize if dimensions exceed max (for API compatibility)
        resize_if_needed(filepath)

        { path: filepath, format: "png" }
      rescue Ferrum::BrowserError, Ferrum::NodeNotFoundError => e
        { error: "Screenshot failed (#{selector || 'page'}): #{e.message}" }
      rescue Ferrum::TimeoutError
        { error: "Screenshot timed out. The page may be loading slowly — try again." }
      end

      private

      def resize_if_needed(filepath)
        image = MiniMagick::Image.open(filepath)
        width = image.width
        height = image.height

        return if width <= MAX_DIMENSION && height <= MAX_DIMENSION

        # Calculate scale factor to fit within MAX_DIMENSION
        scale = [MAX_DIMENSION.to_f / width, MAX_DIMENSION.to_f / height].min
        new_width = (width * scale).to_i
        new_height = (height * scale).to_i

        image.resize("#{new_width}x#{new_height}")
        image.write(filepath)
      end
    end
  end
end
