defmodule Rex.ListSubscriptionServer do
  use GenServer

  require Logger

  defstruct subscribers: []

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(_args) do
    {:ok, %__MODULE__{}}
  end

  def subscribe(args) do
    GenServer.call(__MODULE__, {:subscribe, args}, :infinity)
  end

  def publish_to_subscribers(list_state, list_name) do
    GenServer.call(__MODULE__, {:publish_to_subscribers, list_state, list_name})
  end

  @impl GenServer
  def handle_call(
        {:subscribe, [op | args]},
        {pid, _ref} = from,
        %__MODULE__{subscribers: subscribers} = state
      ) do
    pop_from =
      case op do
        "BLPOP" ->
          :left

        "BRPOP" ->
          :right
      end

    monitor_ref = Process.monitor(pid)

    keys = Enum.slice(args, 0..-2//1)

    timeout =
      args
      |> List.last()
      |> Float.parse()
      |> then(fn {v, _} -> v * 1000 end)
      |> trunc()

    if timeout > 0 do
      Process.send_after(__MODULE__, {:timeout, from}, timeout)
    end

    subscribers =
      subscribers ++
        [
          %{
            pop_from: pop_from,
            subscribed_to: keys,
            pid_ref: from,
            monitor_ref: monitor_ref
          }
        ]

    state = %{state | subscribers: subscribers}

    {:reply, :defer, state}
  end

  def handle_call(
        {:publish_to_subscribers, list_state, list_name},
        _from,
        %__MODULE__{subscribers: subscribers} = state
      ) do
    list_state = :queue.to_list(list_state)

    {new_subscribers, new_list_state} = do_publish(list_name, list_state, subscribers)

    {:reply, :queue.from_list(new_list_state), %{state | subscribers: new_subscribers}}
  end

  # is there an item in list_state?
  # if so, find the first thing that subscribes to list_name
  # pop that thing off list_state and send to subscriber
  # remove subscriber from state
  # repeat until list_state is empty
  def do_publish(_list_name, [], subscribers), do: {subscribers, []}

  def do_publish(_list_name, list_state, []), do: {[], list_state}

  def do_publish(list_name, list_state, subscribers) do
    idx =
      Enum.find_index(subscribers, fn %{subscribed_to: subscribed_to} ->
        Enum.member?(subscribed_to, list_name)
      end)

    if idx do
      %{pop_from: pop_from, pid_ref: {pid, _ref}} = Enum.at(subscribers, idx)

      new_list_state =
        case pop_from do
          :left ->
            [el | rest] = list_state

            Process.send(
              pid,
              {:reply_to_blocking_socket,
               [
                 Rex.Protocol.V2.BulkString.new(list_name),
                 Rex.Protocol.V2.BulkString.new(el)
               ]},
              []
            )

            rest

          :right ->
            el = List.last(list_state)

            Process.send(
              pid,
              {:reply_to_blocking_socket,
               [
                 Rex.Protocol.V2.BulkString.new(list_name),
                 Rex.Protocol.V2.BulkString.new(el)
               ]},
              []
            )

            Enum.take(list_state, Enum.count(list_state) - 1)
        end

      do_publish(list_name, new_list_state, List.delete_at(subscribers, idx))
    else
      {subscribers, list_state}
    end
  end

  @impl GenServer
  def handle_info({:timeout, from}, %__MODULE__{subscribers: subscribers} = state) do
    subscribers =
      Enum.reject(subscribers, fn %{pid_ref: pid_ref} ->
        pid_ref == from
      end)

    {:noreply, %{state | subscribers: subscribers}}
  end

  def handle_info(
        {:DOWN, down_ref, :process, down_pid, _reason},
        %__MODULE__{subscribers: subscribers} = state
      ) do
    subscribers =
      Enum.reject(
        subscribers,
        fn %{
             pid_ref: {subscriber_pid, _genserver_ref},
             monitor_ref: monitor_ref
           } ->
          subscriber_pid == down_pid && monitor_ref == down_ref
        end
      )

    {:noreply, %{state | subscribers: subscribers}}
  end
end
