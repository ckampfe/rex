defmodule Rex.ListServer do
  use GenServer
  require Logger

  def start(list_name) do
    GenServer.start(__MODULE__, list_name, name: {:via, Registry, {Registry.Rex, list_name}})
  end

  @impl GenServer
  def init(name) do
    Process.set_label("Rex.ListServer: #{name}")
    {:ok, :queue.new()}
  end

  def lpush(list_name, elements) do
    server = get_or_start(list_name)
    GenServer.call(server, {:lpush, elements})
  end

  def rpush(list_name, elements) do
    server = get_or_start(list_name)
    GenServer.call(server, {:rpush, elements})
  end

  def lpop(list_name, count) do
    case get_or_nil(list_name) do
      nil ->
        nil

      server ->
        GenServer.call(server, {:lpop, count})
    end
  end

  def rpop(list_name, count) do
    case get_or_nil(list_name) do
      nil ->
        nil

      server ->
        GenServer.call(server, {:rpop, count})
    end
  end

  def llen(list_name) do
    case get_or_nil(list_name) do
      nil ->
        0

      server ->
        GenServer.call(server, :llen)
    end
  end

  @impl GenServer
  def handle_call(
        {:lpush, elements},
        _from,
        state
      ) do
    state =
      Enum.reduce(elements, state, fn el, acc ->
        :queue.in_r(el, acc)
      end)

    {:reply, :queue.len(state), state}
  end

  # TODO make rpush also work with blpop/brpop
  def handle_call({:rpush, elements}, _from, state) do
    state =
      Enum.reduce(elements, state, fn el, acc ->
        :queue.in(el, acc)
      end)

    {:reply, :queue.len(state), state}
  end

  def handle_call({:lpop, 1}, _from, state) do
    case :queue.out(state) do
      {{:value, value}, state} ->
        {:reply, value, state}

      {:empty, _q} ->
        {:reply, nil, state}
    end
  end

  def handle_call({:lpop, count}, _from, state) do
    {left, right} = :queue.split(count, state)

    reply = :queue.reverse(left) |> :queue.to_list()

    {:reply, reply, right}
  end

  def handle_call({:rpop, 1}, _from, state) do
    case :queue.out_r(state) do
      {{:value, value}, state} ->
        {:reply, value, state}

      {:empty, _q} ->
        {:reply, nil, state}
    end
  end

  def handle_call({:rpop, count}, _from, state) do
    {left, right} = :queue.split(count, state)
    reply = :queue.reverse(right) |> :queue.to_list()

    {:reply, reply, left}
  end

  def handle_call(:llen, _from, state) do
    {:reply, :queue.len(state), state}
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
