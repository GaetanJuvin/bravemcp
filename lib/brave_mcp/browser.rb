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
