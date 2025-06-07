defmodule Rex.Handler do
  use ThousandIsland.Handler
  alias Rex.Protocol.V2

  @impl ThousandIsland.Handler
  def handle_connection(socket, state) do
    {:ok, {_ip, _port} = address} = ThousandIsland.Socket.peername(socket)
    {:ok, _pid} = Registry.register(Registry.Rex, address, nil)
    {:continue, state}
  end

  @impl ThousandIsland.Handler
  def handle_data(data, socket, state) do
    case V2.decode(data) do
      {:ok, decoded} ->
        result = Rex.interpret(decoded) |> IO.inspect(label: "interp response")

        response = V2.encode(result) |> IO.inspect(label: "encoded response")

        ThousandIsland.Socket.send(socket, response)

        {:continue, state}

      _ ->
        {:close, state}
    end
  end
end
