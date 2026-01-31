# lib/brave_mcp/tools/content.rb
require "base64"

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
          { content: element.property("outerHTML") }
        else
          { content: page.body }
        end
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
          { content: element.text }
        else
          { content: page.at_css("body").text }
        end
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
      description "Take a screenshot of the page or a specific element"

      arguments do
        optional(:selector).filled(:string).description("CSS selector to screenshot specific element")
        optional(:full_page).filled(:bool).description("Capture the full scrollable page")
      end

      def call(selector: nil, full_page: false)
        page = BraveMcp::Browser.page

        options = { encoding: :base64 }
        options[:full] = true if full_page
        options[:selector] = selector if selector

        data = page.screenshot(**options)

        { image: data, format: "png" }
      end
    end
  end
end
