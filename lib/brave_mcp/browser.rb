# lib/brave_mcp/browser.rb
require "fileutils"

module BraveMcp
  class Browser
    DEFAULT_PORT = 9222
    DEFAULT_PROFILE_DIR = File.expand_path("~/.brave-mcp-profile")
    BRAVE_PATH = "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
    MAX_CONNECT_RETRIES = 10
    RETRY_DELAY = 1 # seconds

    class << self
      def instance
        return @instance if @instance && alive?
        connect_or_launch
      end

      def alive?
        return false unless @instance
        @instance.page.evaluate("1 + 1") == 2
      rescue
        false
      end

      def connect_or_launch(port: DEFAULT_PORT)
        @console_logs = []
        connect_to_existing(port)
      rescue Ferrum::Error
        launch_brave(port: port)
        connect_with_retry(port)
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

      def brave_pid
        @brave_pid
      end

      private

      def connect_to_existing(port)
        @instance = Ferrum::Browser.new(url: "http://localhost:#{port}")
        setup_console_listener
        @instance
      end

      def connect_with_retry(port)
        retries = 0
        begin
          @instance = Ferrum::Browser.new(url: "http://localhost:#{port}")
          setup_console_listener
          @instance
        rescue Ferrum::Error => e
          retries += 1
          if retries < MAX_CONNECT_RETRIES
            sleep RETRY_DELAY
            retry
          end
          raise ConnectionError, "Launched Brave but cannot connect on port #{port} after #{MAX_CONNECT_RETRIES} attempts. " \
            "Check that Brave is installed at: #{brave_path}"
        end
      end

      def launch_brave(port: DEFAULT_PORT)
        profile_dir = ENV.fetch("BRAVE_MCP_PROFILE", DEFAULT_PROFILE_DIR)
        FileUtils.mkdir_p(profile_dir)

        $stderr.puts "Launching Brave with profile: #{profile_dir}"

        @brave_pid = Process.spawn(
          brave_path,
          "--remote-debugging-port=#{port}",
          "--user-data-dir=#{profile_dir}",
          "--no-first-run",
          [:out, :err] => File::NULL
        )
        Process.detach(@brave_pid)
      end

      def brave_path
        ENV.fetch("BRAVE_MCP_PATH", BRAVE_PATH)
      end

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
