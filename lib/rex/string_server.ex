defmodule Rex.StringServer do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl GenServer
  def init(_args) do
    Process.set_label("Rex.StringServer")
    {:ok, %{}}
  end

  def get(key) do
    server = name(key)
    GenServer.call(server, {:get, key})
  end

  def set(key, value) do
    server = name(key)
    GenServer.call(server, {:set, key, value})
  end

  @impl GenServer
  def handle_call({:get, key}, _from, state) do
    {:reply, Map.get(state, key), state}
  end

  def handle_call({:set, key, value}, _from, state) do
    state = Map.put(state, key, value)
    {:reply, "OK", state}
  end

  defp name(key) do
    {
      :via,
      PartitionSupervisor,
      {Rex.PartitionStringSupervisor, key}
    }
  end
end
