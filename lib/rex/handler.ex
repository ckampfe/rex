defmodule Rex.Handler do
  use ThousandIsland.Handler
  alias Rex.Protocol.V2
  require Logger

  @impl ThousandIsland.Handler
  def handle_connection(socket, state) do
    {:ok, {ip, port} = address} = ThousandIsland.Socket.peername(socket)

    {:ok, pid} = Registry.register(Registry.Rex, address, nil)

    Logger.debug("connection #{inspect(ip)}:#{inspect(port)} to #{inspect(pid)}")

    {:continue, state}
  end

  @impl ThousandIsland.Handler
  def handle_data(data, socket, state) do
    IO.inspect(socket)

    case V2.decode(data) do
      {:ok, decoded} ->
        Logger.debug("request decoded: #{inspect(decoded)}")

        # result =
        case Rex.interpret(decoded) do
          :defer ->
            Logger.debug("deferring")
            # notice that there is no socket send here
            {:continue, state}

          result ->
            Logger.debug("interpret result: #{inspect(result)}")

            reply = V2.encode(result)

            Logger.debug("reply encode result: #{inspect(reply)}")

            ThousandIsland.Socket.send(socket, reply)

            {:continue, state}
        end

        # _ ->
        #   {:close, state}
    end
  end

  @impl ThousandIsland.Handler
  def handle_close(_socket, _state) do
    Logger.debug("socket closed")
    :ok
  end

  @impl ThousandIsland.Handler
  def handle_error(reason, _socket, _state) do
    Logger.debug("tcp error #{inspect(reason)}")
    :ok
  end

  @impl ThousandIsland.Handler
  def handle_timeout(_socket, _state) do
    Logger.debug("timed out!")
    :ok
  end

  @impl GenServer
  def handle_info({:reply_to_blocking_socket, to_publish}, {socket, _state} = socketstate) do
    IO.inspect(socketstate)
    dbg(to_publish)
    reply = V2.encode(to_publish)
    ThousandIsland.Socket.send(socket, reply)
    {:noreply, socketstate}
  end
end
