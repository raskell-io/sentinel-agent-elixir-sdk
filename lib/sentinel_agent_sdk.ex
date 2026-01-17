defmodule SentinelAgentSdk do
  @moduledoc """
  Elixir SDK for building Sentinel proxy agents.

  This SDK provides the tools to build custom agents that integrate with the
  Sentinel proxy. Agents can inspect and modify HTTP requests and responses,
  implement security policies, rate limiting, and more.

  ## Protocol Versions

  The SDK supports two protocol versions:

  - **v1 (Legacy)** - JSON over UDS, simple request/response
  - **v2 (Current)** - Enhanced protocol with capabilities, health checks, metrics

  ## Quick Start (v1)

      defmodule MyAgent do
        use SentinelAgentSdk.Agent

        @impl true
        def name, do: "my-agent"

        @impl true
        def on_request(request) do
          if Request.path_starts_with?(request, "/blocked") do
            Decision.deny()
            |> Decision.with_body("Access denied")
          else
            Decision.allow()
          end
        end
      end

      # Run the agent
      SentinelAgentSdk.run(MyAgent)

  ## Quick Start (v2)

      defmodule MyAgentV2 do
        use SentinelAgentSdk.V2.Agent

        @impl true
        def name, do: "my-agent-v2"

        @impl true
        def capabilities do
          AgentCapabilities.new()
          |> AgentCapabilities.with_name(name())
          |> AgentCapabilities.handles_request_headers()
          |> AgentCapabilities.supports_health_check()
        end

        @impl true
        def on_request(request) do
          Decision.allow()
        end

        @impl true
        def health_check do
          HealthStatus.healthy()
        end
      end

      # Run with v2 protocol
      SentinelAgentSdk.V2.run(MyAgentV2)

  ## Core Modules (v1)

  - `SentinelAgentSdk.Agent` - The behaviour for implementing agents
  - `SentinelAgentSdk.ConfigurableAgent` - For agents with typed configuration
  - `SentinelAgentSdk.Request` - Request wrapper with helper functions
  - `SentinelAgentSdk.Response` - Response wrapper with helper functions
  - `SentinelAgentSdk.Decision` - Fluent API for building agent responses
  - `SentinelAgentSdk.Runner` - Agent server and runner

  ## V2 Modules

  - `SentinelAgentSdk.V2` - V2 protocol entry point
  - `SentinelAgentSdk.V2.Agent` - V2 agent behaviour with capabilities
  - `SentinelAgentSdk.V2.ConfigurableAgent` - V2 agent with typed config
  - `SentinelAgentSdk.V2.Types` - V2 protocol types (capabilities, health, metrics)
  - `SentinelAgentSdk.V2.Handler` - V2 event handler
  - `SentinelAgentSdk.V2.Runner` - V2 runner with transport support
  """

  alias SentinelAgentSdk.Runner

  @doc """
  Run an agent with default options.

  ## Options

  - `:socket` - Unix socket path (default: "/tmp/sentinel-agent.sock")
  - `:log_level` - Log level (:debug, :info, :warning, :error)
  - `:json_logs` - Enable JSON log format (default: false)

  ## Example

      SentinelAgentSdk.run(MyAgent, socket: "/var/run/my-agent.sock")
  """
  @spec run(module(), keyword()) :: :ok | {:error, term()}
  def run(agent_module, opts \\ []) do
    Runner.run(agent_module, opts)
  end
end
