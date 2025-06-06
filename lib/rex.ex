defmodule Rex do
  # TODO
  #
  # hashmap ops are absolutely not safe in the presence of parallelism.
  # values can and will be stomped on by parallel processes.
  # maybe we should use the ets table as a hashmap itself,
  # rather than storing a hashmap under a named key
  #
  # write after read is especially not safe, as the read value
  # could have changed out from under you.
  # there is no way to do an atomic CAS operation in ets
  #
  # use a table per hashmap, with a genserver that manages
  # and serializes access to that table? maybe?

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

  def interpret(["HKEYS", hash_name], state) do
    case :ets.lookup(state.table, hash_name) do
      [{_, map}] ->
        Map.keys(map)

      [] ->
        []
    end
  end

  def interpret(["HMGET", hash_name | keys], state) do
    case :ets.lookup(state.table, hash_name) do
      [{_, map}] ->
        keys
        |> Enum.reduce([], fn key, acc ->
          [Map.get(map, key) | acc]
        end)
        |> Enum.reverse()

      [] ->
        []
    end
  end

  def interpret(["HEXISTS", hash_name, key], state) do
    case :ets.lookup(state.table, hash_name) do
      [{_, map}] ->
        if Map.has_key?(map, key) do
          1
        else
          0
        end

      [] ->
        0
    end
  end

  ### END HASH ###
end
