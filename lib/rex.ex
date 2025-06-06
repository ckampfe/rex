defmodule Rex do
  ### MISC ###
  def interpret([bulk_string: "PING"], _state) do
    "PONG"
  end

  def interpret([bulk_string: "COMMAND", bulk_string: "DOCS"], _state) do
    "OK"
  end

  ### END MISC ###

  ### STRING ###

  def interpret([bulk_string: "GET", bulk_string: key], state) do
    case :ets.lookup(state.table, key) do
      [{^key, value}] -> value
      [] -> nil
    end
  end

  def interpret(
        [{:bulk_string, "SET"}, {:bulk_string, key}, {:bulk_string, value}],
        state
      ) do
    :ets.insert(state.table, {key, value})

    "OK"
  end

  ### END STRING ###

  ### HASH ###

  def interpret(
        [{:bulk_string, "HGET"}, {:bulk_string, hash_name}, {:bulk_string, key}],
        state
      ) do
    case :ets.lookup(state.table, hash_name) do
      [{_, map}] -> Map.get(map, key)
      [] -> nil
    end
  end

  def interpret([{:bulk_string, "HGETALL"}, {:bulk_string, hash_name}], state) do
    case :ets.lookup(state.table, hash_name) do
      [{_, map}] -> map
      [] -> nil
    end
  end

  def interpret(
        [{:bulk_string, "HSET"}, {:bulk_string, hash_name} | keypairs],
        state
      ) do
    addition_map =
      keypairs
      |> Enum.chunk_every(2)
      |> Enum.reduce(%{}, fn [{:bulk_string, key}, {:bulk_string, value}], acc ->
        Map.put(acc, key, value)
      end)

    # new_key_count
    {new_map, number_of_keys_added} =
      case :ets.lookup(state.table, hash_name) do
        [{_, current_map}] ->
          new_map = Map.merge(current_map, addition_map)

          {new_map, map_size(new_map) - map_size(current_map)}

        [] ->
          {addition_map, map_size(addition_map)}
      end

    :ets.insert(state.table, {hash_name, new_map})

    number_of_keys_added
  end

  def interpret([{:bulk_string, "HLEN"}, {:bulk_string, hash_name}], state) do
    case :ets.lookup(state.table, {hash_name, :"$__keys"}) do
      [{_, existing_keys}] -> Enum.count(existing_keys)
      [] -> 0
    end
  end

  # def interpret({:array, [{:bulk_string, "HDEL"}, {:bulk_string, hash_name} | keys]}) do
  #   existing_keys =
  #     case :ets.lookup(@hashes_table, {hash_name, :"$__keys"}) do
  #       [{_, existing_keys}] -> existing_keys
  #       [] -> MapSet.new()
  #     end

  #   keys_to_delete =
  #     keys
  #     |> Enum.map(fn {:bulk_string, key} ->
  #       {hash_name, key}
  #     end)
  #     |> MapSet.new()

  #   keys_after_deletion = MapSet.difference(existing_keys, keys_to_delete)

  #   if !Enum.empty?(keys_after_deletion) do
  #     :ets.insert(@hashes_table, {hash_name})
  #   else
  #     :ets.delete(@hashes_table, {hash_name, :"$__keys"})
  #   end
  # end

  ### END HASH ###
end
