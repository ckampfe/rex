defmodule Rex.ListServer do
  use GenServer

  defstruct [:q, :subscribers]

  def start(name) do
    GenServer.start(__MODULE__, name, name: {:via, Registry, {Registry.Rex, name}})
  end

  @impl GenServer
  def init(name) do
    Process.set_label("Rex.ListServer: #{name}")
    {:ok, %__MODULE__{q: :queue.new(), subscribers: :queue.new()}}
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

  # def blpop(list_name, count) do
  # end

  def llen(list_name) do
    case get_or_nil(list_name) do
      nil ->
        0

      server ->
        GenServer.call(server, :llen)
    end
  end

  @impl GenServer
  def handle_call({:lpush, elements}, _from, %{q: q} = state) do
    q =
      Enum.reduce(elements, q, fn el, acc ->
        :queue.cons(el, acc)
      end)

    {:reply, :queue.len(q), %{state | q: q}}
  end

  def handle_call({:rpush, elements}, _from, %{q: q} = state) do
    q =
      Enum.reduce(elements, q, fn el, acc ->
        :queue.in(el, acc)
      end)

    {:reply, :queue.len(q), %{state | q: q}}
  end

  def handle_call({:lpop, 1}, _from, %{q: q} = state) do
    case :queue.out(q) do
      {{:value, value}, q} ->
        {:reply, value, %{state | q: q}}

      {:empty, q} ->
        {:reply, nil, %{state | q: q}}
    end
  end

  def handle_call({:lpop, count}, _from, %{q: q} = state) do
    {left, right} = :queue.split(count, q)
    reply = :queue.reverse(left) |> :queue.to_list()
    {:reply, reply, %{state | q: right}}
  end

  def handle_call({:rpop, 1}, _from, %{q: q} = state) do
    case :queue.out_r(q) do
      {{:value, value}, q} ->
        {:reply, value, %{state | q: q}}

      {:empty, q} ->
        {:reply, nil, %{state | q: q}}
    end
  end

  def handle_call({:rpop, count}, _from, %{q: q} = state) do
    {left, right} = :queue.split(count, q)
    reply = :queue.reverse(right) |> :queue.to_list()
    {:reply, reply, %{state | q: left}}
  end

  def handle_call(:llen, _from, %{q: q} = state) do
    {:reply, :queue.len(q), state}
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
