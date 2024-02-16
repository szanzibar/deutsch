defmodule Deutsch.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      DeutschWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:deutsch, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Deutsch.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Deutsch.Finch},
      # Start a worker by calling: Deutsch.Worker.start_link(arg)
      # {Deutsch.Worker, arg},
      # Start to serve requests, typically the last entry
      DeutschWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Deutsch.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DeutschWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
