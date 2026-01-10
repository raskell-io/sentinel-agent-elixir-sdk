defmodule SentinelAgentSdk do
  @moduledoc """
  Elixir SDK for building Sentinel proxy agents.

  This SDK provides the tools to build custom agents that integrate with the
  Sentinel proxy. Agents can inspect and modify HTTP requests and responses,
  implement security policies, rate limiting, and more.

  ## Quick Start

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

  ## Core Modules

  - `SentinelAgentSdk.Agent` - The behaviour for implementing agents
  - `SentinelAgentSdk.ConfigurableAgent` - For agents with typed configuration
  - `SentinelAgentSdk.Request` - Request wrapper with helper functions
  - `SentinelAgentSdk.Response` - Response wrapper with helper functions
  - `SentinelAgentSdk.Decision` - Fluent API for building agent responses
  - `SentinelAgentSdk.Runner` - Agent server and runner
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
