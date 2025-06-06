defmodule HashTest do
  use ExUnit.Case
  doctest Rex
  import Rex
  alias Rex.State

  setup do
    table = :ets.new(:ok, [:set])
    state = %State{table: table}
    [state: state]
  end

  test "HSET single key new", context do
    assert 1 ==
             interpret(
               [
                 "HSET",
                 "some map",
                 "a key",
                 "a value"
               ],
               context[:state]
             )

    assert "a value" ==
             interpret(
               [
                 "HGET",
                 "some map",
                 "a key"
               ],
               context[:state]
             )

    assert nil ==
             interpret(
               [
                 "HGET",
                 "some map",
                 "no key"
               ],
               context[:state]
             )

    assert nil ==
             interpret(
               [
                 "HGET",
                 "no map",
                 "no key"
               ],
               context[:state]
             )
  end

  test "HSET single key prior", context do
    assert 1 ==
             interpret(
               [
                 "HSET",
                 "some map",
                 "a key",
                 "a value"
               ],
               context[:state]
             )

    assert "a value" ==
             interpret(
               [
                 "HGET",
                 "some map",
                 "a key"
               ],
               context[:state]
             )

    assert 0 ==
             interpret(
               [
                 "HSET",
                 "some map",
                 "a key",
                 "a new value"
               ],
               context[:state]
             )

    assert "a new value" ==
             interpret(
               [
                 "HGET",
                 "some map",
                 "a key"
               ],
               context[:state]
             )
  end

  test "HSET multiple keys new", context do
    assert 2 ==
             interpret(
               [
                 "HSET",
                 "some map",
                 "a",
                 "b",
                 "c",
                 "d"
               ],
               context[:state]
             )

    assert "b" ==
             interpret(
               [
                 "HGET",
                 "some map",
                 "a"
               ],
               context[:state]
             )

    assert "d" ==
             interpret(
               [
                 "HGET",
                 "some map",
                 "c"
               ],
               context[:state]
             )
  end

  test "HLEN", context do
    assert 0 ==
             interpret(
               [
                 "HLEN",
                 "doesn't exist"
               ],
               context[:state]
             )

    assert 2 ==
             interpret(
               [
                 "HSET",
                 "some map",
                 "a",
                 "b",
                 "c",
                 "d"
               ],
               context[:state]
             )

    assert 2 ==
             interpret(
               [
                 "HLEN",
                 "some map"
               ],
               context[:state]
             )
  end

  test "HDEL", context do
    assert 2 ==
             interpret(
               [
                 "HSET",
                 "some map",
                 "a",
                 "b",
                 "c",
                 "d"
               ],
               context[:state]
             )

    assert 0 == interpret(["HDEL", "some map", "nokey"], context[:state])

    assert 2 == interpret(["HLEN", "some map"], context[:state])

    assert 1 == interpret(["HDEL", "some map", "a"], context[:state])

    assert 1 == interpret(["HLEN", "some map"], context[:state])

    assert 1 == interpret(["HDEL", "some map", "b", "c", "d", "e", "f"], context[:state])

    assert 0 == interpret(["HLEN", "some map"], context[:state])
  end
end
