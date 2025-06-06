# TODO
#
# should probably have ProtocolV2 and ProtocolV3,
# but need to walk this back and start with V2 since
# since V2 appears to be the default, with V3 being opt in
#
# remains to be seen how to default to encoding maps as arrays, or
# whatever else V2 requires
defmodule Rex.Protocol.V2 do
  def decode(s) do
    {:ok, decoded, ""} = do_decode(s)
    {:ok, decoded}
  end

  defp do_decode(s) do
    case s do
      <<"$", body::binary>> ->
        {length, <<"\r\n", remainder::binary>>} = Integer.parse(body)

        case length do
          0 ->
            {:ok, {:bulk_string, ""}, ""}

          _ ->
            <<s::bytes-size(length), "\r\n", rest::binary>> = remainder
            {:ok, {:bulk_string, s}, rest}
        end

      <<"*", body::binary>> ->
        [number_of_elements, commands] =
          body
          |> String.split("\r\n", parts: 2)

        number_of_elements = String.to_integer(number_of_elements)

        case number_of_elements do
          0 ->
            {:ok, [], ""}

          _ ->
            {rest, decoded} =
              Enum.reduce(1..number_of_elements, {commands, []}, fn _, {remaining, acc} ->
                {:ok, decoded, rest} = do_decode(remaining)
                {rest, [decoded | acc]}
              end)

            decoded = Enum.reverse(decoded)

            {:ok, decoded, rest}
        end

      <<"+", body::binary>> ->
        [s, remaining] = String.split(body, "\r\n", parts: 2)
        {:ok, {:simple_string, s}, remaining}

      <<"-", body::binary>> ->
        [s, remaining] = String.split(body, "\r\n", parts: 2)
        {:ok, {:simple_error, s}, remaining}

      <<":", body::binary>> ->
        case Integer.parse(body) do
          {i, "\r\n"} ->
            {:ok, i, ""}

          {i, <<"\r\n", rest::binary>>} ->
            {:ok, i, rest}
        end
    end
  end

  def encode(message) when is_binary(message) do
    ["+", message, "\r\n"]
  end

  def encode(message) when is_integer(message) do
    [":", Integer.to_string(message), "\r\n"]
  end

  def encode([]), do: "*0\r\n"

  def encode(message) when is_list(message) do
    length = Enum.count(message)

    [
      "*",
      to_string(length),
      "\r\n",
      Enum.map(message, fn el ->
        encode(el)
      end)
    ]
  end

  def encode(nil) do
    "_\r\n"
  end

  def encode(message) when is_boolean(message) do
    if message do
      "#t\r\n"
    else
      "#f\r\n"
    end
  end

  def encode(message) when message == %{} do
    encode([])
  end

  def encode(message) when is_map(message) do
    message
    |> Enum.flat_map(fn {k, v} -> [k, v] end)
    |> encode()
  end

  def encode({:simple_error, error}) do
    ["-", error, "\r\n"]
  end
end
