# lib/brave_mcp/browser.rb
module BraveMcp
  class Browser
    DEFAULT_PORT = 9222

    class << self
      def instance
        return @instance if @instance && alive?
        connect
      end

      def alive?
        return false unless @instance
        @instance.page.evaluate("1 + 1") == 2
      rescue
        false
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
