defmodule HashTest do
  use ExUnit.Case
  import Rex

  setup do
    %{map: :rand.bytes(40)}
  end

  test "HSET single key new", %{map: map} do
    assert 1 ==
             interpret([
               "HSET",
               map,
               "a key",
               "a value"
             ])

    assert "a value" ==
             interpret([
               "HGET",
               map,
               "a key"
             ])

    assert nil ==
             interpret([
               "HGET",
               map,
               "no key"
             ])

    assert nil ==
             interpret([
               "HGET",
               "no map",
               "no key"
             ])
  end

  test "HSET single key prior", %{map: map} do
    assert 1 ==
             interpret([
               "HSET",
               map,
               "a key",
               "a value"
             ])

    assert "a value" ==
             interpret([
               "HGET",
               map,
               "a key"
             ])

    assert 0 ==
             interpret([
               "HSET",
               map,
               "a key",
               "a new value"
             ])

    assert "a new value" ==
             interpret([
               "HGET",
               map,
               "a key"
             ])
  end

  test "HSET multiple keys new", %{map: map} do
    assert 2 ==
             interpret([
               "HSET",
               map,
               "a",
               "b",
               "c",
               "d"
             ])

    assert "b" ==
             interpret([
               "HGET",
               map,
               "a"
             ])

    assert "d" ==
             interpret([
               "HGET",
               map,
               "c"
             ])
  end

  test "HLEN", %{map: map} do
    assert 0 ==
             interpret([
               "HLEN",
               "doesn't exist"
             ])

    assert 2 ==
             interpret([
               "HSET",
               map,
               "a",
               "b",
               "c",
               "d"
             ])

    assert 2 ==
             interpret([
               "HLEN",
               map
             ])
  end

  test "HDEL", %{map: map} do
    assert 2 ==
             interpret([
               "HSET",
               map,
               "a",
               "b",
               "c",
               "d"
             ])

    assert 0 == interpret(["HDEL", map, "nokey"])

    assert 2 == interpret(["HLEN", map])

    assert 1 == interpret(["HDEL", map, "a"])

    assert 1 == interpret(["HLEN", map])

    assert 1 == interpret(["HDEL", map, "b", "c", "d", "e", "f"])

    assert 0 == interpret(["HLEN", map])
  end

  test "HKEYS", %{map: map} do
    assert [] == interpret(["HKEYS", "doesntexist"])

    assert 2 ==
             interpret([
               "HSET",
               map,
               "a",
               "b",
               "c",
               "d"
             ])

    assert ["a", "c"] == interpret(["HKEYS", map])
  end

  test "HMGET", %{map: map} do
    assert 2 ==
             interpret([
               "HSET",
               map,
               "a",
               "b",
               "c",
               "d"
             ])

    assert ["b", "d", nil] ==
             interpret([
               "HMGET",
               map,
               "a",
               "c",
               "x"
             ])
  end

  test "HEXISTS", %{map: map} do
    assert 2 ==
             interpret([
               "HSET",
               map,
               "a",
               "b",
               "c",
               "d"
             ])

    assert 1 ==
             interpret([
               "HEXISTS",
               map,
               "a"
             ])

    assert 0 ==
             interpret([
               "HEXISTS",
               map,
               "nokey"
             ])

    assert 0 ==
             interpret([
               "HEXISTS",
               map,
               "nokey"
             ])
  end
end
