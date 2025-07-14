defmodule Rex.HashServer do
  use GenServer

  def start(name) do
    GenServer.start(__MODULE__, name, name: {:via, Registry, {Registry.Rex, name}})
  end

  @impl GenServer
  def init(name) do
    Process.set_label("Rex.HashServer: #{name}")
    {:ok, %{}}
  end

  def hget(hash_name, key) do
    case get_or_nil(hash_name) do
      nil ->
        nil

      server ->
        GenServer.call(server, {:hget, key})
    end
  end

  def hset(hash_name, keypairs) do
    server = get_or_start(hash_name)
    GenServer.call(server, {:hset, keypairs})
  end

  def hlen(hash_name) do
    case get_or_nil(hash_name) do
      nil ->
        0

      server ->
        GenServer.call(server, :hlen)
    end
  end

  def hkeys(hash_name) do
    case get_or_nil(hash_name) do
      nil ->
        []

      server ->
        GenServer.call(server, :hkeys)
    end
  end

  def hmget(hash_name, keys) do
    case get_or_nil(hash_name) do
      nil ->
        Enum.map(keys, fn _key -> nil end)

      server ->
        GenServer.call(server, {:hmget, keys})
    end
  end

  def hexists(hash_name, key) do
    case get_or_nil(hash_name) do
      nil ->
        0

      server ->
        GenServer.call(server, {:hexists, key})
    end
  end

  def hgetall(hash_name) do
    case get_or_nil(hash_name) do
      nil ->
        []

      server ->
        GenServer.call(server, :hgetall)
    end
  end

  def hdel(hash_name, keys) do
    case get_or_nil(hash_name) do
      nil ->
        0

      server ->
        GenServer.call(server, {:hdel, keys})
    end
  end

  def hincrby(hash_name, key, increment) when is_integer(increment) do
    server = get_or_start(hash_name)
    GenServer.call(server, {:hincrby, key, increment})
  end

  @impl GenServer
  def handle_call({:hget, key}, _from, state) do
    {:reply, Map.get(state, key), state}
  end

  def handle_call({:hset, keypairs}, _from, state) do
    if Kernel.rem(Enum.count(keypairs), 2) == 0 do
      addition_map =
        keypairs
        |> Enum.chunk_every(2)
        |> Enum.reduce(%{}, fn [key, value], acc ->
          Map.put(acc, key, value)
        end)

      new_map = Map.merge(state, addition_map)

      keys_inserted =
        Kernel.map_size(new_map) - Kernel.map_size(state)

      {:reply, keys_inserted, new_map}
    else
      {
        :reply,
        {:error, "ERR wrong number of arguments for 'hset' command"},
        state
      }
    end
  end

  def handle_call(:hlen, _from, state) do
    {:reply, Kernel.map_size(state), state}
  end

  def handle_call(:hkeys, _from, state) do
    {:reply, Map.keys(state), state}
  end

  def handle_call({:hmget, keys}, _from, state) do
    reply =
      keys
      |> Enum.reduce([], fn key, acc ->
        [Map.get(state, key) | acc]
      end)
      |> Enum.reverse()

    {:reply, reply, state}
  end

  def handle_call({:hexists, key}, _from, state) do
    reply =
      if Map.has_key?(state, key) do
        1
      else
        0
      end

    {:reply, reply, state}
  end

  def handle_call(:hgetall, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:hdel, keys}, _from, state) do
    new_map = Map.drop(state, keys)

    reply =
      MapSet.intersection(
        MapSet.new(keys),
        MapSet.new(Map.keys(state))
      )
      |> Enum.count()

    if Enum.empty?(new_map) do
      {:stop, :normal, reply, new_map}
    else
      {:reply, reply, new_map}
    end
  end

  def handle_call({:hincrby, key, increment}, _from, state) do
    value = Map.get(state, key, 0)
    new_value = value + increment
    state = Map.put(state, key, new_value)
    {:reply, new_value, state}
  end

  defp get_or_start(hash_name) do
    case Registry.lookup(Registry.Rex, hash_name) do
      [{pid, _}] ->
        if Process.alive?(pid) do
          pid
        else
          {:ok, pid} = start(hash_name)
          pid
        end

      [] ->
        {:ok, pid} = start(hash_name)
        pid
    end
  end

  defp get_or_nil(hash_name) do
    case Registry.lookup(Registry.Rex, hash_name) do
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
