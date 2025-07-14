defmodule Rex.SetServer do
  use GenServer

  def start(name) do
    GenServer.start(__MODULE__, name, name: {:via, Registry, {Registry.Rex, name}})
  end

  @impl GenServer
  def init(name) do
    Process.set_label("Rex.SetServer: #{name}")
    {:ok, MapSet.new()}
  end

  def sadd(set_name, members) do
    server = get_or_start(set_name)
    GenServer.call(server, {:sadd, members})
  end

  def smembers(set_name) do
    case get_or_nil(set_name) do
      nil ->
        []

      server ->
        GenServer.call(server, :smembers)
    end
  end

  def sismember(set_name, member) do
    case get_or_nil(set_name) do
      nil ->
        0

      server ->
        GenServer.call(server, {:sismember, member})
    end
  end

  @impl GenServer
  def handle_call({:sadd, members}, _from, state) do
    members_set = MapSet.new(members)
    new_members = MapSet.difference(members_set, state)

    state = MapSet.union(state, new_members)

    {:reply, Enum.count(new_members), state}
  end

  def handle_call(:smembers, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:sismember, member}, _from, state) do
    reply =
      if MapSet.member?(state, member) do
        1
      else
        0
      end

    {:reply, reply, state}
  end

  defp get_or_start(name) do
    case Registry.lookup(Registry.Rex, name) do
      [{pid, _}] ->
        if Process.alive?(pid) do
          pid
        else
          {:ok, pid} = start(name)
          pid
        end

      [] ->
        {:ok, pid} = start(name)
        pid
    end
  end

  defp get_or_nil(name) do
    case Registry.lookup(Registry.Rex, name) do
      [{pid, _}] ->
        # there can be a delay between process shutdown
        # and process deregistration
        if Process.alive?(pid) do
          pid
        else
          nil
        end

      _ ->
        nil
    end
  end
end
