# Sentinel Agent Elixir SDK

An Elixir SDK for building agents that integrate with the [Sentinel](https://github.com/raskell-io/sentinel) reverse proxy.

## Installation

Add `sentinel_agent_sdk` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sentinel_agent_sdk, github: "raskell-io/sentinel-agent-elixir-sdk"}
  ]
end
```

Or install from source:

```bash
cd sentinel-agent-elixir-sdk

# Using mise (recommended)
mise install
mix deps.get

# Run tests
mix test
```

## Quick Start

Create a simple agent that blocks requests to admin paths:

```elixir
defmodule MyAgent do
  use SentinelAgentSdk.Agent

  @impl true
  def name, do: "my-agent"

  @impl true
  def on_request(request) do
    if Request.path_starts_with?(request, "/admin") do
      Decision.deny()
      |> Decision.with_body("Access denied")
    else
      Decision.allow()
    end
  end
end

# Run the agent
SentinelAgentSdk.run(MyAgent, socket: "/tmp/my-agent.sock")
```

## Features

- **Simple API**: Implement the `Agent` behaviour with intuitive callback functions
- **Fluent Decision Builder**: Pipe operators to build complex responses
- **Request/Response Wrappers**: Ergonomic access to headers, body, and metadata
- **Typed Configuration**: Use `ConfigurableAgent` for structured configuration
- **Protocol Compatible**: Full compatibility with Sentinel's agent protocol

## Core Concepts

### Agent

The `Agent` behaviour is the main abstraction for building agents. Implement the callbacks you need:

```elixir
defmodule MyAgent do
  use SentinelAgentSdk.Agent

  @impl true
  def name, do: "my-agent"

  @impl true
  def on_configure(config) do
    # Optional: Handle configuration from proxy
    :ok
  end

  @impl true
  def on_request(request) do
    # Optional: Process request headers
    Decision.allow()
  end

  @impl true
  def on_request_body(request) do
    # Optional: Process request body (when enabled)
    Decision.allow()
  end

  @impl true
  def on_response(request, response) do
    # Optional: Process response headers
    Decision.allow()
  end

  @impl true
  def on_response_body(request, response) do
    # Optional: Process response body (when enabled)
    Decision.allow()
  end

  @impl true
  def on_request_complete(request, status, duration_ms) do
    # Optional: Called when request processing completes
    :ok
  end
end
```

### Request

The `Request` module provides ergonomic access to HTTP request data:

```elixir
def on_request(request) do
  alias SentinelAgentSdk.Request

  # Method checks
  if Request.is_get?(request), do: # ...
  if Request.is_post?(request), do: # ...

  # Path access
  path = Request.path(request)           # Full path with query string
  path_only = Request.path_only(request) # Path without query string

  # Path matching
  if Request.path_starts_with?(request, "/api"), do: # ...
  if Request.path_equals?(request, "/health"), do: # ...

  # Query parameters
  page = Request.query(request, "page")           # Single value
  tags = Request.query_all(request, "tag")        # All values

  # Headers (case-insensitive)
  auth = Request.header(request, "Authorization")
  has_auth = Request.has_header?(request, "Authorization")

  # Common headers
  host = Request.host(request)
  user_agent = Request.user_agent(request)
  content_type = Request.content_type(request)

  # Body access
  body_bytes = Request.body(request)
  body_str = Request.body_str(request)
  body_json = Request.body_json(request)

  # Metadata
  client_ip = Request.client_ip(request)
  correlation_id = Request.correlation_id(request)

  Decision.allow()
end
```

### Response

The `Response` module provides similar access for HTTP responses:

```elixir
def on_response(request, response) do
  alias SentinelAgentSdk.Response

  # Status checks
  status = Response.status_code(response)
  if Response.is_success?(response), do: # ...      # 2xx
  if Response.is_redirect?(response), do: # ...     # 3xx
  if Response.is_client_error?(response), do: # ... # 4xx
  if Response.is_server_error?(response), do: # ... # 5xx
  if Response.is_error?(response), do: # ...        # 4xx or 5xx

  # Headers
  content_type = Response.content_type(response)
  location = Response.location(response)  # For redirects

  # Content type checks
  if Response.is_json?(response), do: # ...
  if Response.is_html?(response), do: # ...

  # Body
  body_bytes = Response.body(response)
  body_str = Response.body_str(response)
  body_json = Response.body_json(response)

  Decision.allow()
end
```

### Decision

The `Decision` module provides a fluent API for building agent responses:

```elixir
alias SentinelAgentSdk.Decision

# Basic decisions
Decision.allow()                    # Pass through
Decision.deny()                     # Block with 403
Decision.unauthorized()             # Block with 401
Decision.rate_limited()             # Block with 429
Decision.block(500)                 # Block with custom status
Decision.redirect("/login")         # Redirect (302)
Decision.redirect_permanent("/new") # Redirect (301)

# Customizing block responses
Decision.deny()
|> Decision.with_body("Access denied")
|> Decision.with_block_header("X-Blocked-Reason", "policy")

# JSON responses
Decision.block(400)
|> Decision.with_json_body(%{"error" => "Invalid request"})

# Header mutations
Decision.allow()
|> Decision.add_request_header("X-Processed", "true")
|> Decision.remove_request_header("X-Internal")
|> Decision.add_response_header("X-Cache", "HIT")
|> Decision.remove_response_header("Server")

# Audit metadata
Decision.deny()
|> Decision.with_tag("security")
|> Decision.with_tags(["blocked", "suspicious"])
|> Decision.with_rule_id("RULE_001")
|> Decision.with_confidence(0.95)
|> Decision.with_reason_code("RATE_EXCEEDED")
|> Decision.with_metadata("client_ip", "1.2.3.4")
```

### Configurable Agent

For agents that need typed configuration:

```elixir
defmodule MyConfig do
  defstruct rate_limit: 100, enabled: true, blocked_paths: []
end

defmodule MyAgent do
  use SentinelAgentSdk.ConfigurableAgent

  @impl true
  def name, do: "my-agent"

  @impl true
  def default_config, do: %MyConfig{}

  @impl true
  def parse_config(config_map) do
    %MyConfig{
      rate_limit: Map.get(config_map, "rate_limit", 100),
      enabled: Map.get(config_map, "enabled", true),
      blocked_paths: Map.get(config_map, "blocked_paths", [])
    }
  end

  @impl true
  def on_config_applied(config) do
    IO.puts("Config applied: rate_limit=#{config.rate_limit}")
    :ok
  end

  @impl true
  def on_request(request, config) do
    if not config.enabled do
      Decision.allow()
    else
      blocked = Enum.any?(config.blocked_paths, fn path ->
        Request.path_starts_with?(request, path)
      end)

      if blocked, do: Decision.deny(), else: Decision.allow()
    end
  end
end
```

## Running Agents

### Programmatic

```elixir
# Simple usage
SentinelAgentSdk.run(MyAgent, socket: "/tmp/my-agent.sock")

# With options
SentinelAgentSdk.run(MyAgent,
  socket: "/tmp/my-agent.sock",
  log_level: :debug,
  json_logs: true
)
```

### As a Script

```bash
# Run example agent
elixir examples/simple_agent.exs --socket /tmp/my-agent.sock

# With options
elixir examples/simple_agent.exs --socket /tmp/my-agent.sock --log-level debug
```

## Sentinel Configuration

Configure Sentinel to use your agent:

```kdl
agents {
    agent "my-agent" {
        type "custom"
        transport "unix_socket" {
            path "/tmp/my-agent.sock"
        }
        events ["request_headers", "response_headers"]
        timeout_ms 1000
        failure_mode "open"

        config {
            rate_limit 100
            enabled true
            blocked_paths ["/admin", "/internal"]
        }
    }
}

routes {
    route "api" {
        matches { path_prefix "/api" }
        upstream "backend"
        agents ["my-agent"]
    }
}
```

## Examples

See the `examples/` directory for complete examples:

- `simple_agent.exs` - Basic request filtering
- `configurable_agent.exs` - Rate limiting with configuration
- `body_inspection_agent.exs` - Request/response body inspection

## Protocol Compatibility

This SDK implements Sentinel's agent protocol version 1:

- Unix socket communication with length-prefixed JSON
- Support for all event types (request headers, body, response headers, body, complete)
- Full decision types (allow, block, redirect, challenge)
- Header mutations and audit metadata

## Development

This project uses [mise](https://mise.jdx.dev/) for tool management.

```bash
# Install tools via mise
mise install

# Get dependencies
mix deps.get

# Run tests
mix test

# Type checking
mix dialyzer

# Format code
mix format

# Lint
mix lint
```

## License

Apache License 2.0 - see LICENSE file for details.
