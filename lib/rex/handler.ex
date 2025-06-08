defmodule Rex.Handler do
  use ThousandIsland.Handler
  alias Rex.Protocol.V2
  require Logger

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
        Logger.debug("request decoded: #{inspect(decoded)}")

        result = Rex.interpret(decoded)

        Logger.debug("interpret result: #{result}")

        reply = V2.encode(result)

        Logger.debug("reply encode result: #{inspect(reply)}")

        ThousandIsland.Socket.send(socket, reply)

        {:continue, state}

        # _ ->
        #   {:close, state}
    end
  end
end
