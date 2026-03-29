# lib/brave_mcp/browser.rb
require "fileutils"

module BraveMcp
  class Browser
    DEFAULT_PORT = 9222
    DEFAULT_PROFILE_DIR = File.expand_path("~/.brave-mcp-profile")
    BRAVE_PATH = "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
    MAX_CONNECT_RETRIES = 10
    RETRY_DELAY = 1 # seconds
    DEFAULT_VIEWPORT_WIDTH = 1280
    DEFAULT_VIEWPORT_HEIGHT = 800

    class << self
      def instance
        return @instance if @instance && alive?
        connect_or_launch
      end

      def alive?
        return false unless @instance
        if @page
          @page.evaluate("1 + 1") == 2
        else
          # No page yet -- assume the recently-created instance is still
          # alive.  If it isn't, page creation will fail and we reconnect.
          true
        end
      rescue
        false
      end

      def connect_or_launch(port: DEFAULT_PORT)
        @console_logs = []
        @page = nil # clear stale page reference from previous connection
        connect_to_existing(port)
      rescue Ferrum::Error, Errno::ECONNREFUSED
        if brave_running?
          # Brave is open but without --remote-debugging-port
          # Restart it with the debug port enabled
          $stderr.puts "Brave is running but debug port #{port} is not open. Restarting with remote debugging..."
          kill_brave
          sleep 1
        end
        launch_brave(port: port)
        connect_with_retry(port)
      end

      def page
        instance # ensure browser is connected
        unless @page
          begin
            @page = @instance.create_page
            setup_page
          rescue Ferrum::Error
            # Browser connection may have died since startup -- reconnect
            @instance = nil
            @page = nil
            instance
            @page = @instance.create_page
            setup_page
          end
        end
        @page
      end

      def console_logs
        @console_logs ||= []
      end

      def clear_console_logs!
        @console_logs = []
      end

      def reset!
        @page&.close
        @page = nil
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
      end

      def connect_with_retry(port)
        retries = 0
        begin
          @instance = Ferrum::Browser.new(url: "http://localhost:#{port}")
        rescue Ferrum::Error, Errno::ECONNREFUSED => e
          retries += 1
          if retries < MAX_CONNECT_RETRIES
            $stderr.puts "Waiting for Brave to start (attempt #{retries}/#{MAX_CONNECT_RETRIES})..."
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

      def brave_running?
        !`pgrep -f "Brave Browser"`.strip.empty?
      rescue
        false
      end

      def kill_brave
        system("pkill", "-f", "Brave Browser")
      rescue
        nil
      end

      def brave_path
        ENV.fetch("BRAVE_MCP_PATH", BRAVE_PATH)
      end

      def setup_page
        setup_viewport
        setup_console_listener
      end

      def setup_viewport
        # Override the viewport so the browser renders the page at a fixed
        # size independent of the actual window/tab dimensions.  This also
        # forces Chrome to composite the page even when the tab is in the
        # background, which prevents blank/white screenshots after scrolling.
        width  = ENV.fetch("BRAVE_MCP_VIEWPORT_WIDTH",  DEFAULT_VIEWPORT_WIDTH).to_i
        height = ENV.fetch("BRAVE_MCP_VIEWPORT_HEIGHT", DEFAULT_VIEWPORT_HEIGHT).to_i

        @page.command("Emulation.setDeviceMetricsOverride",
          width: width,
          height: height,
          deviceScaleFactor: 1,
          mobile: false
        )
      end

      def setup_console_listener
        @page.on(:console) do |message|
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
