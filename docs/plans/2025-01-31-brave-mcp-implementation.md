# BraveMCP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Ruby MCP server that connects Claude Code to Brave browser via Chrome DevTools Protocol.

**Architecture:** Standalone STDIO server using fast-mcp gem for MCP protocol, ferrum gem for CDP connection. Assumes Brave is already running with `--remote-debugging-port=9222`.

**Tech Stack:** Ruby, fast-mcp, ferrum

---

## Task 1: Project Setup

**Files:**
- Create: `Gemfile`
- Create: `bin/brave_mcp`
- Create: `lib/brave_mcp.rb`

**Step 1: Create Gemfile**

```ruby
# Gemfile
source "https://rubygems.org"

gem "fast-mcp"
gem "ferrum"
```

**Step 2: Create main library file**

```ruby
# lib/brave_mcp.rb
require "fast_mcp"
require "ferrum"

module BraveMcp
  VERSION = "0.1.0"
end

require_relative "brave_mcp/browser"
require_relative "brave_mcp/server"
```

**Step 3: Create executable**

```ruby
#!/usr/bin/env ruby
# bin/brave_mcp

require_relative "../lib/brave_mcp"

BraveMcp::Server.run
```

**Step 4: Make executable and install deps**

Run: `chmod +x bin/brave_mcp && bundle install`
Expected: Gems install successfully

**Step 5: Commit**

```bash
git add Gemfile Gemfile.lock bin/brave_mcp lib/brave_mcp.rb
git commit -m "feat: initial project setup with fast-mcp and ferrum"
```

---

## Task 2: Browser Connection

**Files:**
- Create: `lib/brave_mcp/browser.rb`

**Step 1: Create browser wrapper**

```ruby
# lib/brave_mcp/browser.rb
module BraveMcp
  class Browser
    DEFAULT_PORT = 9222

    class << self
      def instance
        @instance ||= connect
      end

      def connect(port: DEFAULT_PORT)
        @instance = Ferrum::Browser.new(url: "http://localhost:#{port}")
      rescue Ferrum::Error => e
        raise ConnectionError, "Cannot connect to Brave on port #{port}. " \
          "Launch Brave with: /Applications/Brave\\ Browser.app/Contents/MacOS/Brave\\ Browser --remote-debugging-port=#{port}"
      end

      def page
        instance.page
      end

      def reset!
        @instance&.quit
        @instance = nil
      end
    end

    class ConnectionError < StandardError; end
  end
end
```

**Step 2: Test connection manually**

Run: `bundle exec ruby -e "require_relative 'lib/brave_mcp'; BraveMcp::Browser.instance; puts 'Connected!'"`
Expected: Either "Connected!" or clear error message about launching Brave

**Step 3: Commit**

```bash
git add lib/brave_mcp/browser.rb
git commit -m "feat: add browser connection wrapper with ferrum"
```

---

## Task 3: MCP Server Setup

**Files:**
- Create: `lib/brave_mcp/server.rb`

**Step 1: Create server with fast-mcp**

```ruby
# lib/brave_mcp/server.rb
module BraveMcp
  class Server
    def self.run
      server = FastMcp::Server.new(name: "brave-mcp", version: VERSION)

      # Tools will be registered here
      register_tools(server)

      server.start
    end

    def self.register_tools(server)
      Dir[File.join(__dir__, "tools", "*.rb")].each { |f| require f }

      # Register all tool classes
      Tools.constants.each do |const|
        tool_class = Tools.const_get(const)
        server.register_tool(tool_class) if tool_class < FastMcp::Tool
      end
    end
  end
end
```

**Step 2: Create tools directory structure**

Run: `mkdir -p lib/brave_mcp/tools`

**Step 3: Commit**

```bash
git add lib/brave_mcp/server.rb
git commit -m "feat: add MCP server setup with tool auto-discovery"
```

---

## Task 4: Navigation Tools

**Files:**
- Create: `lib/brave_mcp/tools/navigation.rb`

**Step 1: Create navigation tools**

```ruby
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
      end
    end

    class Back < FastMcp::Tool
      description "Go back in browser history"

      arguments {}

      def call
        BraveMcp::Browser.page.back
        { success: true, url: BraveMcp::Browser.page.current_url }
      end
    end

    class Forward < FastMcp::Tool
      description "Go forward in browser history"

      arguments {}

      def call
        BraveMcp::Browser.page.forward
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
```

**Step 2: Test server starts**

Run: `timeout 2 bundle exec bin/brave_mcp 2>&1 || true`
Expected: Server starts (or timeout, which is expected for STDIO server)

**Step 3: Commit**

```bash
git add lib/brave_mcp/tools/navigation.rb
git commit -m "feat: add navigation tools (navigate, reload, back, forward, get_url)"
```

---

## Task 5: Content Tools

**Files:**
- Create: `lib/brave_mcp/tools/content.rb`

**Step 1: Create content tools**

```ruby
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
```

**Step 2: Commit**

```bash
git add lib/brave_mcp/tools/content.rb
git commit -m "feat: add content tools (get_html, get_text, get_title, screenshot)"
```

---

## Task 6: Automation Tools

**Files:**
- Create: `lib/brave_mcp/tools/automation.rb`

**Step 1: Create automation tools**

```ruby
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

        element.hover
        { success: true }
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
      end
    end
  end
end
```

**Step 2: Commit**

```bash
git add lib/brave_mcp/tools/automation.rb
git commit -m "feat: add automation tools (click, type, fill, select, hover, scroll, focus)"
```

---

## Task 7: JavaScript Tools

**Files:**
- Create: `lib/brave_mcp/tools/javascript.rb`

**Step 1: Create JavaScript tools**

```ruby
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
```

**Step 2: Commit**

```bash
git add lib/brave_mcp/tools/javascript.rb
git commit -m "feat: add JavaScript tools (evaluate, wait_for_selector, wait_for_navigation)"
```

---

## Task 8: Element Inspection Tools

**Files:**
- Create: `lib/brave_mcp/tools/inspection.rb`

**Step 1: Create inspection tools**

```ruby
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
```

**Step 2: Commit**

```bash
git add lib/brave_mcp/tools/inspection.rb
git commit -m "feat: add inspection tools (get_element_info, query_selector_all)"
```

---

## Task 9: DevTools - Console Logs

**Files:**
- Create: `lib/brave_mcp/tools/devtools.rb`
- Modify: `lib/brave_mcp/browser.rb`

**Step 1: Update browser to capture console logs**

```ruby
# lib/brave_mcp/browser.rb
module BraveMcp
  class Browser
    DEFAULT_PORT = 9222

    class << self
      def instance
        @instance ||= connect
      end

      def connect(port: DEFAULT_PORT)
        @console_logs = []
        @instance = Ferrum::Browser.new(url: "http://localhost:#{port}")
        setup_console_listener
        @instance
      rescue Ferrum::Error => e
        raise ConnectionError, "Cannot connect to Brave on port #{port}. " \
          "Launch Brave with: /Applications/Brave\\ Browser.app/Contents/MacOS/Brave\\ Browser --remote-debugging-port=#{port}"
      end

      def page
        instance.page
      end

      def console_logs
        @console_logs ||= []
      end

      def clear_console_logs!
        @console_logs = []
      end

      def reset!
        @instance&.quit
        @instance = nil
        @console_logs = []
      end

      private

      def setup_console_listener
        @instance.on(:console) do |message|
          @console_logs << {
            level: message.type,
            text: message.text,
            timestamp: Time.now.iso8601
          }
        end
      end
    end

    class ConnectionError < StandardError; end
  end
end
```

**Step 2: Create devtools console tools**

```ruby
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
```

**Step 3: Commit**

```bash
git add lib/brave_mcp/browser.rb lib/brave_mcp/tools/devtools.rb
git commit -m "feat: add console log capture and devtools tools"
```

---

## Task 10: DevTools - Network Requests

**Files:**
- Modify: `lib/brave_mcp/tools/devtools.rb`

**Step 1: Add network tools**

Add to `lib/brave_mcp/tools/devtools.rb`:

```ruby
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
```

**Step 2: Commit**

```bash
git add lib/brave_mcp/tools/devtools.rb
git commit -m "feat: add network request tools (get_network_requests, get_request_details, clear_network)"
```

---

## Task 11: DevTools - Performance & Storage

**Files:**
- Modify: `lib/brave_mcp/tools/devtools.rb`

**Step 1: Add performance and storage tools**

Add to `lib/brave_mcp/tools/devtools.rb`:

```ruby
    class GetPerformanceMetrics < FastMcp::Tool
      description "Get page performance metrics"

      arguments {}

      def call
        page = BraveMcp::Browser.page

        metrics = page.evaluate <<~JS
          (() => {
            const perf = performance;
            const timing = perf.timing;
            const navigation = perf.getEntriesByType('navigation')[0] || {};

            return {
              loadTime: timing.loadEventEnd - timing.navigationStart,
              domContentLoaded: timing.domContentLoadedEventEnd - timing.navigationStart,
              firstPaint: perf.getEntriesByName('first-paint')[0]?.startTime || null,
              firstContentfulPaint: perf.getEntriesByName('first-contentful-paint')[0]?.startTime || null,
              domInteractive: timing.domInteractive - timing.navigationStart,
              resourceCount: perf.getEntriesByType('resource').length,
              memory: perf.memory ? {
                usedJSHeapSize: perf.memory.usedJSHeapSize,
                totalJSHeapSize: perf.memory.totalJSHeapSize
              } : null
            };
          })()
        JS

        { metrics: metrics }
      end
    end

    class GetCookies < FastMcp::Tool
      description "Get cookies for the current page"

      arguments do
        optional(:name).filled(:string).description("Filter by cookie name")
      end

      def call(name: nil)
        cookies = BraveMcp::Browser.page.cookies.all

        if name
          cookie = cookies[name]
          return { cookie: cookie&.to_h } if cookie
          return { error: "Cookie not found: #{name}" }
        end

        { cookies: cookies.transform_values(&:to_h) }
      end
    end

    class SetCookie < FastMcp::Tool
      description "Set a cookie"

      arguments do
        required(:name).filled(:string).description("Cookie name")
        required(:value).filled(:string).description("Cookie value")
        optional(:domain).filled(:string).description("Cookie domain")
        optional(:path).filled(:string).description("Cookie path")
        optional(:expires).filled(:integer).description("Expiration timestamp")
        optional(:http_only).filled(:bool).description("HTTP only flag")
        optional(:secure).filled(:bool).description("Secure flag")
      end

      def call(name:, value:, domain: nil, path: nil, expires: nil, http_only: nil, secure: nil)
        options = { name: name, value: value }
        options[:domain] = domain if domain
        options[:path] = path if path
        options[:expires] = expires if expires
        options[:httpOnly] = http_only unless http_only.nil?
        options[:secure] = secure unless secure.nil?

        BraveMcp::Browser.page.cookies.set(**options)
        { success: true }
      end
    end

    class DeleteCookies < FastMcp::Tool
      description "Delete cookies"

      arguments do
        optional(:name).filled(:string).description("Cookie name to delete (all if omitted)")
      end

      def call(name: nil)
        if name
          BraveMcp::Browser.page.cookies.remove(name: name)
        else
          BraveMcp::Browser.page.cookies.clear
        end
        { success: true }
      end
    end

    class GetLocalStorage < FastMcp::Tool
      description "Get localStorage data"

      arguments do
        optional(:key).filled(:string).description("Specific key to get (all if omitted)")
      end

      def call(key: nil)
        page = BraveMcp::Browser.page

        if key
          value = page.evaluate("localStorage.getItem(#{key.to_json})")
          { key: key, value: value }
        else
          data = page.evaluate("Object.fromEntries(Object.entries(localStorage))")
          { data: data }
        end
      end
    end

    class SetLocalStorage < FastMcp::Tool
      description "Set a localStorage value"

      arguments do
        required(:key).filled(:string).description("Storage key")
        required(:value).filled(:string).description("Storage value")
      end

      def call(key:, value:)
        page = BraveMcp::Browser.page
        page.execute("localStorage.setItem(#{key.to_json}, #{value.to_json})")
        { success: true }
      end
    end
```

**Step 2: Commit**

```bash
git add lib/brave_mcp/tools/devtools.rb
git commit -m "feat: add performance and storage tools (metrics, cookies, localStorage)"
```

---

## Task 12: Error Handling & Polish

**Files:**
- Modify: `lib/brave_mcp/server.rb`
- Modify: `lib/brave_mcp.rb`

**Step 1: Add error handling wrapper**

Update `lib/brave_mcp/server.rb`:

```ruby
# lib/brave_mcp/server.rb
module BraveMcp
  class Server
    def self.run
      server = FastMcp::Server.new(name: "brave-mcp", version: VERSION)

      register_tools(server)

      # Attempt connection on startup to fail fast with helpful message
      begin
        Browser.instance
        $stderr.puts "BraveMCP connected to Brave browser"
      rescue Browser::ConnectionError => e
        $stderr.puts "Warning: #{e.message}"
        $stderr.puts "Tools will attempt to connect on first use."
      end

      server.start
    end

    def self.register_tools(server)
      Dir[File.join(__dir__, "tools", "*.rb")].sort.each { |f| require f }

      Tools.constants.each do |const|
        tool_class = Tools.const_get(const)
        server.register_tool(tool_class) if tool_class < FastMcp::Tool
      end
    end
  end
end
```

**Step 2: Update main require file**

```ruby
# lib/brave_mcp.rb
require "fast_mcp"
require "ferrum"

module BraveMcp
  VERSION = "0.1.0"

  module Tools
    # Tools will be auto-loaded
  end
end

require_relative "brave_mcp/browser"
require_relative "brave_mcp/server"
```

**Step 3: Commit**

```bash
git add lib/brave_mcp/server.rb lib/brave_mcp.rb
git commit -m "feat: add startup connection check and polish"
```

---

## Task 13: Claude Code Integration

**Files:**
- Update user's Claude settings (manual step)

**Step 1: Test the server manually**

Launch Brave:
```bash
/Applications/Brave\ Browser.app/Contents/MacOS/Brave\ Browser --remote-debugging-port=9222 &
```

Test connection:
```bash
bundle exec ruby -e "
  require_relative 'lib/brave_mcp'
  puts 'Connecting...'
  BraveMcp::Browser.instance
  puts 'Connected!'
  puts 'Current URL: ' + BraveMcp::Browser.page.current_url
"
```

**Step 2: Document integration**

The user should add to their `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "brave": {
      "command": "/Users/gaetanjuvin/Project/BraveMCP/bin/brave_mcp"
    }
  }
}
```

**Step 3: Final commit**

```bash
git add -A
git commit -m "chore: complete BraveMCP implementation" --allow-empty
```

---

## Summary

After completing all tasks, you will have:

- **26 MCP tools** for browser automation and debugging
- **Navigation:** navigate, reload, back, forward, get_url
- **Content:** get_html, get_text, get_title, screenshot
- **Automation:** click, type, fill, select, hover, scroll, focus
- **JavaScript:** evaluate, wait_for_selector, wait_for_navigation
- **Inspection:** get_element_info, query_selector_all
- **DevTools:** get_console_logs, clear_console, get_network_requests, get_request_details, clear_network, get_performance_metrics, get_cookies, set_cookie, delete_cookies, get_local_storage, set_local_storage
