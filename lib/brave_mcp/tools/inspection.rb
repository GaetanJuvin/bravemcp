# lib/brave_mcp/tools/inspection.rb
module BraveMcp
  module Tools
    class GetElementInfo < FastMcp::Tool
      description "Get detailed information about an element"

      arguments do
        required(:selector).filled(:string).description("CSS selector of the element")
      end

      def call(selector:)
        page = BraveMcp::Browser.page
        element = page.at_css(selector)
        return { error: "Element not found: #{selector}" } unless element

        {
          tag: element.tag_name,
          text: element.text.strip[0..200],
          attributes: element.attributes,
          visible: element.visible?,
          bounds: element.bounding_rect
        }
      end
    end

    class QuerySelectorAll < FastMcp::Tool
      description "Find all elements matching a selector"

      arguments do
        required(:selector).filled(:string).description("CSS selector to search for")
        optional(:limit).filled(:integer).description("Maximum number of results (default: 10)")
      end

      def call(selector:, limit: 10)
        page = BraveMcp::Browser.page
        elements = page.css(selector)

        results = elements.first(limit).map.with_index do |el, i|
          {
            index: i,
            tag: el.tag_name,
            text: el.text.strip[0..100],
            id: el.attribute("id"),
            class: el.attribute("class")
          }
        end

        {
          count: elements.size,
          showing: results.size,
          elements: results
        }
      end
    end
  end
end
