defmodule ProtocolV2Test do
  use ExUnit.Case
  import Rex.Protocol.V2
  doctest Rex

  test "decodes simple strings" do
    assert {:ok, {:simple_string, "OK"}} = decode("+OK\r\n")
  end

  test "decodes simple errors" do
    assert {:ok, {:simple_error, "ERROR"}} = decode("-ERROR\r\n")
  end

  test "decodes integers" do
    assert {:ok, 1} = decode(":1\r\n")
    assert {:ok, 1} = decode(":+1\r\n")
    assert {:ok, -1} = decode(":-1\r\n")
    assert {:ok, 0} = decode(":0\r\n")
  end

  test "decodes bulk strings" do
    assert {:ok, {:bulk_string, ""}} = decode("$0\r\n\r\n")
    assert {:ok, {:bulk_string, "hello"}} = decode("$5\r\nhello\r\n")
  end

  test "decodes arrays" do
    assert {:ok, []} = decode("*0\r\n")

    assert {:ok, [1]} = decode("*1\r\n:1\r\n")

    assert {:ok, [{:simple_string, "OK"}, {:bulk_string, "hello"}]} =
             decode("*2\r\n+OK\r\n$5\r\nhello\r\n")

    assert {:ok, [1, {:simple_string, "OK"}]} =
             decode("*2\r\n:1\r\n+OK\r\n")
  end

  test "encodes simple strings" do
    assert ["+", "", "\r\n"] = encode("")
    assert ["+", "OK", "\r\n"] = encode("OK")
  end

  test "encodes simple errors" do
    assert ["-", "", "\r\n"] = encode({:simple_error, ""})
    assert ["-", "SYNTAX syntax error", "\r\n"] = encode({:simple_error, "SYNTAX syntax error"})
  end

  test "encodes integers" do
    assert [":", "0", "\r\n"] = encode(0)
    assert [":", "-1", "\r\n"] = encode(-1)
    assert [":", "1", "\r\n"] = encode(1)
  end

  # test "encodes bulk strings"

  test "encodes arrays" do
    assert "*0\r\n" = encode([])
    assert ["*", "1", "\r\n", [[":", "1", "\r\n"]]] = encode([1])

    assert [
             "*",
             "2",
             "\r\n",
             [
               [":", "1", "\r\n"],
               ["+", "OK", "\r\n"]
             ]
           ] = encode([1, "OK"])
  end

  test "encodes maps (as arrays. RESP2 does not have maps)" do
    assert "*0\r\n" = encode(%{})

    assert ["*", "2", "\r\n", [["+", "hello", "\r\n"], [":", "1", "\r\n"]]] =
             encode(%{"hello" => 1})
  end

  test "encodes nil" do
    assert "_\r\n" = encode(nil)
  end

  test "encodes booleans" do
    assert "#f\r\n" = encode(false)
    assert "#t\r\n" = encode(true)
  end
end
