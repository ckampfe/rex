defmodule ListTest do
  use ExUnit.Case
  import Rex

  require Logger

  setup do
    %{list: :rand.bytes(40)}
  end

  test "LPUSH", %{list: list} do
    assert 1 ==
             interpret([
               "LPUSH",
               list,
               "a key"
             ])

    assert 2 ==
             interpret([
               "LPUSH",
               list,
               "a key"
             ])

    assert 3 ==
             interpret([
               "LPUSH",
               list,
               "a key"
             ])

    assert 6 ==
             interpret([
               "LPUSH",
               list,
               "a",
               "b",
               "c"
             ])
  end

  test "RPUSH", %{list: list} do
    assert 1 ==
             interpret([
               "RPUSH",
               list,
               "a key"
             ])

    assert 2 ==
             interpret([
               "RPUSH",
               list,
               "a key"
             ])

    assert 3 ==
             interpret([
               "RPUSH",
               list,
               "a key"
             ])

    assert 6 ==
             interpret([
               "RPUSH",
               list,
               "a",
               "b",
               "c"
             ])
  end

  test "LPOP", %{list: list} do
    assert nil ==
             interpret([
               "LPOP",
               list
             ])

    assert 1 ==
             interpret([
               "RPUSH",
               list,
               "a key"
             ])

    assert "a key" ==
             interpret([
               "LPOP",
               list
             ])

    assert 3 ==
             interpret([
               "RPUSH",
               list,
               "a",
               "b",
               "c"
             ])

    assert "a" ==
             interpret([
               "LPOP",
               list
             ])

    assert "b" ==
             interpret([
               "LPOP",
               list
             ])

    assert "c" ==
             interpret([
               "LPOP",
               list
             ])
  end

  test "RPOP", %{list: list} do
    assert nil ==
             interpret([
               "RPOP",
               list
             ])

    assert 1 ==
             interpret([
               "RPUSH",
               list,
               "a key"
             ])

    assert "a key" ==
             interpret([
               "RPOP",
               list
             ])

    assert 3 ==
             interpret([
               "RPUSH",
               list,
               "a",
               "b",
               "c"
             ])

    assert "c" ==
             interpret([
               "RPOP",
               list
             ])

    assert "b" ==
             interpret([
               "RPOP",
               list
             ])

    assert "a" ==
             interpret([
               "RPOP",
               list
             ])
  end

  test "LLEN", %{list: list} do
    assert 0 == interpret(["LLEN", list])

    assert 3 ==
             interpret([
               "RPUSH",
               list,
               "a",
               "b",
               "c"
             ])

    assert 3 == interpret(["LLEN", list])

    assert "a" ==
             interpret([
               "LPOP",
               list
             ])

    assert 2 == interpret(["LLEN", list])
  end

  test "BLPOP waits for LPUSH and receives the next pushed element", %{list: list} do
    assert :defer == interpret(["BLPOP", list, "0"])

    interpret(["LPUSH", list, "a"])

    assert_receive {:reply_to_blocking_socket,
                    [
                      %Rex.Protocol.V2.BulkString{s: ^list},
                      %Rex.Protocol.V2.BulkString{s: "a"}
                    ]},
                   1_000
  end

  test "BLPOP returns an element already in the list", %{list: list} do
    interpret(["LPUSH", list, "a"])

    assert "a" == interpret(["BLPOP", list, "0"])
  end

  test "BLPOP removes its subscription on timeout", %{list: list} do
    this = self()

    # 50ms
    assert :defer == interpret(["BLPOP", list, "0.05"])

    assert %Rex.ListSubscriptionServer{subscribers: [%{pid_ref: {^this, _}}]} =
             :sys.get_state(Rex.ListSubscriptionServer)

    Process.sleep(55)

    assert %Rex.ListSubscriptionServer{subscribers: []} =
             :sys.get_state(Rex.ListSubscriptionServer)
  end

  test "BLPOP removes its subscription on disconnect", %{list: list} do
    # spawn, so faking it's in its own process, like it would be
    # if it was a real tcp connection in a ThousandIsland.Handler
    this = self()

    blpop_pid =
      spawn(fn ->
        result = interpret(["BLPOP", list, "0"])

        send(this, {:blpop_result, result})

        receive do
          {:stop, from} -> send(from, {:ok, self()})
        end
      end)

    assert_receive {:blpop_result, :defer}, 100

    assert %Rex.ListSubscriptionServer{subscribers: [%{pid_ref: {^blpop_pid, _}}]} =
             :sys.get_state(Rex.ListSubscriptionServer)

    send(blpop_pid, {:stop, this})

    assert_receive {:ok, ^blpop_pid}, 100

    assert %Rex.ListSubscriptionServer{subscribers: []} =
             :sys.get_state(Rex.ListSubscriptionServer)
  end
end
