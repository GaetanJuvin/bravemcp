# BraveMCP

An MCP (Model Context Protocol) server that provides browser automation capabilities for the Brave browser. Enables AI models like Claude to control and interact with web browsers through a standardized interface.

## Features

- **Navigation** - Navigate URLs, reload, back/forward, get current URL
- **DOM Interaction** - Click, type, fill forms, select dropdowns, hover, scroll, focus
- **Content Extraction** - Get HTML, text, page title, take screenshots
- **DOM Inspection** - Query elements, get element info and attributes
- **JavaScript Execution** - Run scripts, wait for selectors/navigation
- **DevTools** - Console logs, network requests, performance metrics
- **Storage** - Cookies and localStorage management

## Prerequisites

- Ruby 3.x
- Bundler
- Brave Browser
- ImageMagick (for screenshot resizing)

## Installation

```bash
git clone <repository-url>
cd BraveMCP
bundle install
```

## Usage

### 1. Run the MCP server

The server automatically launches Brave with a dedicated profile (`~/.brave-mcp-profile`). No manual browser launch needed.

```bash
bin/brave_mcp
```

On first run, sign into your accounts in the Brave window that opens. Your sessions persist across restarts since the profile is saved to disk.

If Brave is already running with `--remote-debugging-port=9222`, the server connects to it instead of launching a new instance.

### 2. Configure Claude Code

Add to your Claude Code MCP settings:

```json
{
  "mcpServers": {
    "brave": {
      "command": "/path/to/BraveMCP/bin/brave_mcp"
    }
  }
}
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `BRAVE_MCP_PROFILE` | `~/.brave-mcp-profile` | Path to the browser profile directory |
| `BRAVE_MCP_PATH` | `/Applications/Brave Browser.app/Contents/MacOS/Brave Browser` | Path to the Brave executable |

## Available Tools

| Category | Tools |
|----------|-------|
| **Navigation** | `navigate`, `reload`, `back`, `forward`, `get_url` |
| **Automation** | `click`, `type`, `fill`, `select`, `hover`, `scroll`, `focus` |
| **Content** | `get_html`, `get_text`, `get_title`, `screenshot` |
| **Inspection** | `get_element_info`, `query_selector_all` |
| **JavaScript** | `evaluate`, `wait_for_selector`, `wait_for_navigation` |
| **Console** | `get_console_logs`, `clear_console` |
| **Network** | `get_network_requests`, `get_request_details`, `clear_network` |
| **Performance** | `get_performance_metrics` |
| **Cookies** | `get_cookies`, `set_cookie`, `delete_cookies` |
| **Storage** | `get_local_storage`, `set_local_storage` |

## Dependencies

- [fast-mcp](https://github.com/contextco/fast-mcp) - MCP server framework
- [ferrum](https://github.com/rubycdp/ferrum) - Chrome DevTools Protocol driver

## License

MIT
