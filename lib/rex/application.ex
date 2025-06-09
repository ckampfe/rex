defmodule Rex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: Rex.Worker.start_link(arg)
      # {Rex.Worker, arg}
      {Registry, keys: :unique, name: Registry.Rex},
      {
        PartitionSupervisor,
        child_spec: Rex.StringServer.child_spec([]),
        name: Rex.PartitionStringSupervisor,
        partitions: System.schedulers_online()
      },
      {ThousandIsland, port: 6379, handler_module: Rex.Handler}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Rex.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
