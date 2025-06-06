defmodule Rex do
  ### MISC ###
  def interpret(["PING"], _state) do
    "PONG"
  end

  def interpret(["COMMAND", "DOCS"], _state) do
    "OK"
  end

  ### END MISC ###

  ### STRING ###

  def interpret(["GET", key], state) do
    case :ets.lookup(state.table, key) do
      [{^key, value}] -> value
      [] -> nil
    end
  end

  def interpret(
        ["SET", key, value],
        state
      ) do
    :ets.insert(state.table, {key, value})

    "OK"
  end

  ### END STRING ###

  ### HASH ###

  def interpret(
        ["HGET", hash_name, key],
        state
      ) do
    case :ets.lookup(state.table, hash_name) do
      [{_, map}] -> Map.get(map, key)
      [] -> nil
    end
  end

  def interpret(["HGETALL", hash_name], state) do
    case :ets.lookup(state.table, hash_name) do
      [{_, map}] -> map
      [] -> nil
    end
  end

  def interpret(
        ["HSET", hash_name | keypairs],
        state
      ) do
    addition_map =
      keypairs
      |> Enum.chunk_every(2)
      |> Enum.reduce(%{}, fn [key, value], acc ->
        Map.put(acc, key, value)
      end)

    # new_key_count
    {new_map, number_of_keys_added} =
      case :ets.lookup(state.table, hash_name) do
        [{_, current_map}] ->
          new_map = Map.merge(current_map, addition_map)

          {new_map, Kernel.map_size(new_map) - Kernel.map_size(current_map)}

        [] ->
          {addition_map, Kernel.map_size(addition_map)}
      end

    :ets.insert(state.table, {hash_name, new_map})

    number_of_keys_added
  end

  def interpret(["HLEN", hash_name], state) do
    case :ets.lookup(state.table, hash_name) do
      [{_, existing_keys}] -> Kernel.map_size(existing_keys)
      [] -> 0
    end
  end

  def interpret(["HDEL", hash_name | keys], state) do
    case :ets.lookup(state.table, hash_name) do
      [{_, map}] ->
        new_map = Map.drop(map, keys)

        :ets.insert(state.table, {hash_name, new_map})

        MapSet.intersection(
          MapSet.new(keys),
          MapSet.new(Map.keys(map))
        )
        |> Enum.count()

      [] ->
        0
    end
  end

  ### END HASH ###
end
