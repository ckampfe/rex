defmodule Rex do
  @strings_table :rex_strings
  @hashes_table :rex_hashes

  ### MISC ###
  def interpret({:array, [bulk_string: "PING"]}) do
    "PONG"
  end

  def interpret({:array, [bulk_string: "COMMAND", bulk_string: "DOCS"]}) do
    "OK"
  end

  ### END MISC ###

  ### STRING ###

  def interpret({:array, [bulk_string: "GET", bulk_string: key]}) do
    case :ets.lookup(@strings_table, key) do
      [{^key, value}] -> value
      [] -> nil
    end
  end

  def interpret({:array, [{:bulk_string, "SET"}, {:bulk_string, key}, {:bulk_string, value}]}) do
    :ets.insert(@strings_table, {key, value})

    "OK"
  end

  ### END STRING ###

  ### HASH ###

  def interpret(
        {:array, [{:bulk_string, "HGET"}, {:bulk_string, hash_name}, {:bulk_string, key}]}
      ) do
    case :ets.lookup(@hashes_table, {hash_name, key}) do
      [{_, value}] -> value
      [] -> nil
    end
  end

  def interpret({:array, [{:bulk_string, "HGETALL"}, {:bulk_string, hash_name}]}) do
    result =
      @hashes_table
      |> :ets.match({{hash_name, :"$1"}, :"$2"})
      |> Enum.filter(fn
        [:"$__keys", _] ->
          false

        _ ->
          true
      end)
      |> Enum.map(fn [k, v] -> {k, v} end)
      |> Enum.into(%{})

    if Enum.empty?(result) do
      []
    else
      result
    end
  end

  def interpret({:array, [{:bulk_string, "HSET"}, {:bulk_string, hash_name} | keypairs]}) do
    existing_keys =
      case :ets.lookup(@hashes_table, {hash_name, :"$__keys"}) do
        [{_, existing_keys}] -> existing_keys
        [] -> MapSet.new()
      end

    keys_only =
      keypairs
      |> Enum.chunk_every(2)
      |> Enum.map(fn [{:bulk_string, key}, _value] -> key end)
      |> Enum.into(MapSet.new())

    new_key_count = MapSet.difference(keys_only, existing_keys) |> Enum.count()

    updated_keyset = MapSet.union(existing_keys, keys_only)

    insertables =
      keypairs
      |> Enum.chunk_every(2)
      |> Enum.map(fn [{:bulk_string, key}, {:bulk_string, value}] ->
        {{hash_name, key}, value}
      end)

    insertables = insertables ++ [{{hash_name, :"$__keys"}, updated_keyset}]

    :ets.insert(@hashes_table, insertables)

    new_key_count
  end

  def interpret({:array, [{:bulk_string, "HLEN"}, {:bulk_string, hash_name}]}) do
    case :ets.lookup(@hashes_table, {hash_name, :"$__keys"}) do
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
