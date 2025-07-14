# TODO
#
# should probably have ProtocolV2 and ProtocolV3,
# but need to walk this back and start with V2 since
# since V2 appears to be the default, with V3 being opt in
#
# remains to be seen how to default to encoding maps as arrays, or
# whatever else V2 requires
defmodule Rex.Protocol.V2 do
  @bulk_string_type "$"
  @array_type "*"
  @simple_string_type "+"
  @integer_type ":"
  @simple_error_type "-"

  def decode(s) do
    {:ok, decoded, ""} = do_decode(s)
    {:ok, decoded}
  end

  defp do_decode(s) do
    case s do
      <<@bulk_string_type, body::binary>> ->
        {length, <<"\r\n", remainder::binary>>} = Integer.parse(body)

        case length do
          0 ->
            {:ok, "", ""}

          _ ->
            <<s::bytes-size(length), "\r\n", rest::binary>> = remainder
            {:ok, s, rest}
        end

      <<@array_type, body::binary>> ->
        [number_of_elements, commands] =
          body
          |> :binary.split("\r\n")

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

      <<@simple_string_type, body::binary>> ->
        [s, remaining] = :binary.split(body, "\r\n")

        {:ok, s, remaining}

      <<@integer_type, body::binary>> ->
        case Integer.parse(body) do
          {i, "\r\n"} ->
            {:ok, i, ""}

          {i, <<"\r\n", rest::binary>>} ->
            {:ok, i, rest}
        end

      <<@simple_error_type, body::binary>> ->
        [s, remaining] = :binary.split(body, "\r\n")

        {:ok, {:simple_error, s}, remaining}
    end
  end

  def encode(value) do
    Rex.Protocol.V2.Encode.encode(value)
  end

  defmodule BulkString do
    defstruct [:s]

    def new(s) do
      %__MODULE__{s: s}
    end
  end
end

defprotocol Rex.Protocol.V2.Encode do
  def encode(value)
end

defimpl Rex.Protocol.V2.Encode, for: Rex.Protocol.V2.BulkString do
  def encode(s) do
    # $<length>\r\n<data>\r\n
    ["$", Integer.to_string(byte_size(s.s)), "\r\n", s.s, "\r\n"]
  end
end

defimpl Rex.Protocol.V2.Encode, for: BitString do
  def encode(s) do
    ["+", s, "\r\n"]
  end
end

defimpl Rex.Protocol.V2.Encode, for: Integer do
  def encode(i) do
    [":", Integer.to_string(i), "\r\n"]
  end
end

defimpl Rex.Protocol.V2.Encode, for: Atom do
  def encode(b) do
    case b do
      true ->
        "#t\r\n"

      false ->
        "#f\r\n"

      nil ->
        "_\r\n"

      _ ->
        raise ""
    end
  end
end

defimpl Rex.Protocol.V2.Encode, for: List do
  def encode(list) when list == [], do: "*0\r\n"

  def encode(list) do
    length = Enum.count(list)

    [
      "*",
      to_string(length),
      "\r\n",
      Enum.map(list, fn el ->
        Rex.Protocol.V2.Encode.encode(el)
      end)
    ]
  end
end

defimpl Rex.Protocol.V2.Encode, for: Map do
  def encode(m) do
    m
    |> Enum.flat_map(fn {k, v} -> [k, v] end)
    |> Rex.Protocol.V2.Encode.encode()
  end
end

defimpl Rex.Protocol.V2.Encode, for: Tuple do
  def encode({:error, error}) do
    ["-", error, "\r\n"]
  end
end

defimpl Rex.Protocol.V2.Encode, for: MapSet do
  def encode(set) do
    set
    |> Enum.into([])
    |> Rex.Protocol.V2.Encode.encode()
  end
end
