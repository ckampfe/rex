defmodule Rex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Registry.Rex},
      {
        PartitionSupervisor,
        child_spec: Rex.StringServer.child_spec([]),
        name: Rex.PartitionStringSupervisor,
        partitions: System.schedulers_online()
      },
      {Rex.ListSubscriptionServer, []},
      {ThousandIsland, port: 6379, handler_module: Rex.Handler, read_timeout: :timer.minutes(15)}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Rex.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
