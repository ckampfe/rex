defmodule SetTest do
  use ExUnit.Case
  import Rex

  setup do
    %{set: :rand.bytes(40)}
  end

  test "SADD single key new", %{set: set} do
    assert 1 ==
             interpret([
               "SADD",
               set,
               "a"
             ])
  end

  test "SADD multiple", %{set: set} do
    assert 3 ==
             interpret([
               "SADD",
               set,
               "a",
               "b",
               "c"
             ])
  end

  test "SMEMBERS", %{set: set} do
    assert 3 ==
             interpret([
               "SADD",
               set,
               "a",
               "b",
               "c"
             ])

    assert MapSet.new(["a", "b", "c"]) == interpret(["SMEMBERS", set])
  end

  test "SISMEMBER", %{set: set} do
    assert 3 ==
             interpret([
               "SADD",
               set,
               "a",
               "b",
               "c"
             ])

    assert 1 ==
             interpret([
               "SISMEMBER",
               set,
               "a"
             ])

    assert 0 ==
             interpret([
               "SISMEMBER",
               set,
               "z"
             ])

    assert 0 ==
             interpret([
               "SISMEMBER",
               "doesnt exist",
               "z"
             ])
  end
end
