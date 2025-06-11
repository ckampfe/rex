defmodule ListTest do
  use ExUnit.Case
  import Rex

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
end
