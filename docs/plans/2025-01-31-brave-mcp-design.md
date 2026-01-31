# BraveMCP Design

A Ruby MCP server that connects Claude Code to Brave browser via Chrome DevTools Protocol.

## Architecture

```
┌─────────────┐     stdio/JSON-RPC     ┌─────────────┐     WebSocket/CDP     ┌─────────────┐
│ Claude Code │ ◄──────────────────────► │  BraveMCP   │ ◄────────────────────► │    Brave    │
│             │         MCP            │   (Ruby)    │        :9222          │   Browser   │
└─────────────┘                        └─────────────┘                        └─────────────┘
```

**Stack:**
- MCP framework: `fast-mcp` gem
- CDP client: `ferrum` gem
- Connection: Assumes Brave already running with `--remote-debugging-port=9222`

**Project structure:**
```
brave_mcp/
├── Gemfile
├── bin/
│   └── brave_mcp          # Executable entry point
├── lib/
│   └── brave_mcp/
│       ├── server.rb      # MCP server setup
│       ├── browser.rb     # Ferrum connection wrapper
│       └── tools/         # One file per tool category
│           ├── navigation.rb
│           ├── content.rb
│           ├── automation.rb
│           └── devtools.rb
```

## Tools

### Navigation

| Tool | Description | Parameters |
|------|-------------|------------|
| `navigate` | Go to a URL | `url` (required) |
| `reload` | Reload current page | `ignore_cache` (optional, default false) |
| `back` | Go back in history | none |
| `forward` | Go forward in history | none |
| `get_url` | Get current page URL | none |

### Content

| Tool | Description | Parameters |
|------|-------------|------------|
| `get_html` | Get page HTML | `selector` (optional, full page if omitted) |
| `get_text` | Get visible text content | `selector` (optional) |
| `screenshot` | Capture screenshot | `selector` (optional), `full_page` (optional, default false) |
| `get_title` | Get page title | none |

### DevTools - Console

| Tool | Description | Parameters |
|------|-------------|------------|
| `get_console_logs` | Get browser console messages | `level` (optional: all/log/warn/error), `clear` (optional) |
| `clear_console` | Clear captured console logs | none |

### DevTools - Network

| Tool | Description | Parameters |
|------|-------------|------------|
| `get_network_requests` | Get captured network activity | `filter` (optional: xhr/fetch/document/script/etc) |
| `get_request_details` | Get full request/response for a specific call | `request_id` |
| `clear_network` | Clear captured network logs | none |

### DevTools - Performance & Storage

| Tool | Description | Parameters |
|------|-------------|------------|
| `get_performance_metrics` | Get Core Web Vitals, timing, memory | none |
| `get_cookies` | Get cookies for current domain | `name` (optional filter) |
| `set_cookie` | Set a cookie | `name`, `value`, `domain`, `path`, etc. |
| `delete_cookies` | Clear cookies | `name` (optional, all if omitted) |
| `get_local_storage` | Read localStorage | `key` (optional, all if omitted) |
| `set_local_storage` | Write to localStorage | `key`, `value` |

### Automation - Interaction

| Tool | Description | Parameters |
|------|-------------|------------|
| `click` | Click an element | `selector` (required) |
| `type` | Type text into focused element | `text` (required), `delay` (optional, ms between keys) |
| `fill` | Fill an input field | `selector`, `value` |
| `select` | Select dropdown option | `selector`, `value` or `text` |
| `hover` | Hover over element | `selector` |
| `scroll` | Scroll the page | `x`, `y` or `selector` (scroll element into view) |
| `focus` | Focus an element | `selector` |

### Automation - JavaScript

| Tool | Description | Parameters |
|------|-------------|------------|
| `evaluate` | Run JavaScript in page context | `script` (required) |
| `wait_for_selector` | Wait for element to appear | `selector`, `timeout` (optional, default 5000ms) |
| `wait_for_navigation` | Wait for page load after action | `timeout` (optional) |

### Automation - Inspection

| Tool | Description | Parameters |
|------|-------------|------------|
| `get_element_info` | Get element properties (tag, classes, attributes, bounds) | `selector` |
| `query_selector_all` | Find all matching elements | `selector` → returns count + summary |

## Error Handling

- **Connection errors** → Clear message: "Brave not running on port 9222. Launch with: brave --remote-debugging-port=9222"
- **Selector not found** → Return element not found with suggestion to use `query_selector_all` to explore
- **Timeout errors** → Configurable timeouts, clear timeout messages
- **JavaScript errors** → Captured and returned with stack trace

## Claude Code Integration

Add to `~/.claude/settings.json`:
```json
{
  "mcpServers": {
    "brave": {
      "command": "/Users/gaetanjuvin/Project/BraveMCP/bin/brave_mcp"
    }
  }
}
```

**Workflow:**
1. Launch Brave: `/Applications/Brave\ Browser.app/Contents/MacOS/Brave\ Browser --remote-debugging-port=9222`
2. Start Claude Code
3. Claude can navigate, interact, and debug

## Dependencies

```ruby
# Gemfile
source "https://rubygems.org"

gem "fast-mcp"
gem "ferrum"
```
