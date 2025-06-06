defmodule RexTest do
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
                 {:bulk_string, "HSET"},
                 {:bulk_string, "some map"},
                 {:bulk_string, "a key"},
                 {:bulk_string, "a value"}
               ],
               context[:state]
             )

    assert "a value" ==
             interpret(
               [
                 {:bulk_string, "HGET"},
                 {:bulk_string, "some map"},
                 {:bulk_string, "a key"}
               ],
               context[:state]
             )

    assert nil ==
             interpret(
               [
                 {:bulk_string, "HGET"},
                 {:bulk_string, "some map"},
                 {:bulk_string, "no key"}
               ],
               context[:state]
             )

    assert nil ==
             interpret(
               [
                 {:bulk_string, "HGET"},
                 {:bulk_string, "no map"},
                 {:bulk_string, "no key"}
               ],
               context[:state]
             )
  end

  test "HSET single key prior", context do
  end

  test "HSET multiple keys new", context do
  end
end
