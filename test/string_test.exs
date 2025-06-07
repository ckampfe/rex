defmodule Rex.StringTest do
  use ExUnit.Case
  import Rex

  setup do
    %{k: :rand.bytes(40), v: :rand.bytes(40)}
  end

  test "get/set", %{k: k, v: v} do
    assert "OK" ==
             interpret([
               "SET",
               k,
               v
             ])

    assert v ==
             interpret([
               "GET",
               k
             ])

    assert nil ==
             interpret([
               "GET",
               "no"
             ])
  end
end
