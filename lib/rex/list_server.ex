defmodule Rex.ListServer do
  use GenServer
  require Logger

  # three maps:
  # %{list_name: queue(pid)} where pid is blocking listener
  # %{pid: list(list_name)}
  # %{pid: timer_ref}
  #
  # if there are any blocking listeners, find
  # find other lists the listener is listening on, and remove the listener
  # from those
  #
  #
  # TODO
  #
  # we could maintain separate list servers, and have the state necessary
  # for blocking (list_to_queue, pid_to_list) live in a separate server or servers,
  # that normal list servers have to coordinate with in the case of blpop/brpop

  defstruct lists: %{}, list_to_queue: %{}, pid_to_list: %{}, pid_to_timer: %{}

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(_args) do
    Process.set_label("Rex.ListServer")
    {:ok, %__MODULE__{}}
  end

  def lpush(list_name, elements) do
    GenServer.call(__MODULE__, {:lpush, list_name, elements})
  end

  def rpush(list_name, elements) do
    GenServer.call(__MODULE__, {:rpush, list_name, elements})
  end

  def lpop(list_name, count) do
    GenServer.call(__MODULE__, {:lpop, list_name, count})
  end

  def blpop(lists) do
    last = List.last(lists)

    {timeout, lists} =
      case Float.parse(last) do
        {f, _} ->
          {f, List.delete_at(lists, -1)}

        :error ->
          case Integer.parse(last) do
            {i, _} ->
              {i, List.delete_at(lists, -1)}

            _ ->
              {0, lists}
          end
      end

    GenServer.call(__MODULE__, {:blpop, lists, timeout}, :infinity)
  end

  def rpop(list_name, count) do
    GenServer.call(__MODULE__, {:rpop, list_name, count})
  end

  def llen(list_name) do
    GenServer.call(__MODULE__, {:llen, list_name})
  end

  @impl GenServer
  def handle_call(
        {:lpush, list_name, elements},
        _from,
        %__MODULE__{
          lists: lists,
          list_to_queue: list_to_queue,
          pid_to_list: pid_to_list,
          pid_to_timer: pid_to_timer
        } = state
      ) do
    q = Map.get_lazy(lists, list_name, fn -> :queue.new() end)

    q =
      Enum.reduce(elements, q, fn el, acc ->
        :queue.cons(el, acc)
      end)

    state = put_in(state, [Access.key!(:lists), list_name], q)

    state =
      with pq when not is_nil(pq) <- Map.get(list_to_queue, list_name),
           {{:value, subscriber}, pq} <- :queue.out(pq),
           {{:value, el}, q} <- :queue.out(q) do
        state =
          if timer = Map.get(pid_to_timer, subscriber) do
            Process.cancel_timer(timer)
            pid_to_timer = Map.delete(pid_to_timer, subscriber)
            %{state | pid_to_timer: pid_to_timer}
          else
            state
          end

        GenServer.reply(subscriber, el)

        state = put_in(state, [Access.key!(:lists), list_name], q)
        state = put_in(state, [Access.key!(:list_to_queue), list_name], pq)
        pid_to_list = Map.delete(pid_to_list, subscriber)
        state = %{state | pid_to_list: pid_to_list}
        state
      else
        _ ->
          state
      end

    {:reply, :queue.len(q), state}
  end

  # TODO make rpush also work with blpop/brpop
  def handle_call({:rpush, list_name, elements}, _from, %{lists: lists} = state) do
    q = Map.get_lazy(lists, list_name, fn -> :queue.new() end)

    q =
      Enum.reduce(elements, q, fn el, acc ->
        :queue.in(el, acc)
      end)

    state = put_in(state, [Access.key!(:lists), list_name], q)

    {:reply, :queue.len(q), state}
  end

  def handle_call({:lpop, list_name, 1}, _from, %{lists: lists} = state) do
    q = Map.get_lazy(lists, list_name, fn -> :queue.new() end)

    case :queue.out(q) do
      {{:value, value}, q} ->
        state = put_in(state, [Access.key!(:lists), list_name], q)
        {:reply, value, state}

      {:empty, _q} ->
        {:reply, nil, state}
    end
  end

  def handle_call({:lpop, list_name, count}, _from, %{lists: lists} = state) do
    q = Map.get_lazy(lists, list_name, fn -> :queue.new() end)

    {left, right} = :queue.split(count, q)

    reply = :queue.reverse(left) |> :queue.to_list()

    state = put_in(state, [Access.key!(:lists), list_name], right)

    {:reply, reply, state}
  end

  def handle_call(
        {:blpop, list_names, timeout},
        from,
        %{
          lists: lists,
          list_to_queue: list_to_queue,
          pid_to_list: pid_to_list,
          pid_to_timer: pid_to_timer
        } = state
      ) do
    # if there is something in any of the lists, return it,
    # reading them in order
    #
    # if not, do not reply, but add the caller to the right state
    {el, state} =
      Enum.reduce_while(list_names, {nil, state}, fn list_name, _acc ->
        if q = Map.get(lists, list_name, :queue.new()) do
          case :queue.out(q) do
            {:empty, _} ->
              {:cont, {nil, state}}

            {{:value, el}, q} ->
              state = put_in(state, [Access.key!(:lists), list_name], q)
              {:halt, {el, state}}
          end
        else
          {:cont, {nil, state}}
        end
      end)

    if el do
      {:reply, el, state}
    else
      list_to_queue =
        Enum.reduce(list_names, list_to_queue, fn list_name, acc ->
          q = Map.get(acc, list_name, :queue.new())
          q = :queue.in(from, q)
          Map.put(acc, list_name, q)
        end)

      pid_to_list = Map.put(pid_to_list, from, list_names)

      pid_to_timer =
        if timeout > 0 do
          timer_ref =
            Process.send_after(
              self(),
              {:timeout, from, list_names, trunc(:timer.seconds(timeout))},
              trunc(:timer.seconds(timeout))
            )

          Map.put(pid_to_timer, from, timer_ref)
        else
          pid_to_timer
        end

      state = %{
        state
        | list_to_queue: list_to_queue,
          pid_to_list: pid_to_list,
          pid_to_timer: pid_to_timer
      }

      {:noreply, state}
    end
  end

  def handle_call({:rpop, list_name, 1}, _from, %{lists: lists} = state) do
    q = Map.get_lazy(lists, list_name, fn -> :queue.new() end)

    case :queue.out_r(q) do
      {{:value, value}, q} ->
        state = put_in(state, [Access.key!(:lists), list_name], q)
        {:reply, value, state}

      {:empty, _q} ->
        {:reply, nil, state}
    end
  end

  def handle_call({:rpop, list_name, count}, _from, %{lists: lists} = state) do
    q = Map.get_lazy(lists, list_name, fn -> :queue.new() end)

    {left, right} = :queue.split(count, q)
    reply = :queue.reverse(right) |> :queue.to_list()

    state = put_in(state, [Access.key!(:lists), list_name], left)

    {:reply, reply, state}
  end

  def handle_call({:llen, list_name}, _from, %{lists: lists} = state) do
    q = Map.get_lazy(lists, list_name, fn -> :queue.new() end)
    {:reply, :queue.len(q), state}
  end

  @impl GenServer
  def handle_info(
        {:timeout, from, list_names, timeout},
        %__MODULE__{
          list_to_queue: list_to_queue,
          pid_to_list: pid_to_list,
          pid_to_timer: pid_to_timer
        } =
          state
      ) do
    Logger.debug(
      "timed out after #{timeout}ms: #{inspect(from)} listening for #{inspect(list_names)}, deleting"
    )

    GenServer.reply(from, nil)

    pid_to_list = Map.delete(pid_to_list, from)

    list_to_queue =
      Enum.reduce(list_names, list_to_queue, fn list_name, acc ->
        if q = Map.get(acc, list_name) do
          q = :queue.delete(from, q)
          Map.put(acc, list_name, q)
        else
          acc
        end
      end)

    pid_to_timer = Map.delete(pid_to_timer, from)

    state = %{
      state
      | list_to_queue: list_to_queue,
        pid_to_list: pid_to_list,
        pid_to_timer: pid_to_timer
    }

    {:noreply, state}
  end

  # defp get_or_start(name) do
  #   case Registry.lookup(Registry.Rex, name) do
  #     [{pid, _}] ->
  #       if Process.alive?(pid) do
  #         pid
  #       else
  #         {:ok, pid} = start(name)
  #         pid
  #       end

  #     [] ->
  #       {:ok, pid} = start(name)
  #       pid
  #   end
  # end

  # defp get_or_nil(name) do
  #   case Registry.lookup(Registry.Rex, name) do
  #     [{pid, _}] ->
  #       # there can be a delay between process shutdown
  #       # and process deregistration
  #       if Process.alive?(pid) do
  #         pid
  #       else
  #         nil
  #       end

  #     _ ->
  #       nil
  #   end
  # end
end
