# lib/brave_mcp.rb
require "fast_mcp"
require "ferrum"

module BraveMcp
  VERSION = "0.1.0"
end

require_relative "brave_mcp/browser"
require_relative "brave_mcp/server"
