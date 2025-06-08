defmodule Rex do
  alias Rex.{HashServer, StringServer}

  ### MISC ###
  def interpret(["PING"]) do
    "PONG"
  end

  def interpret(["COMMAND", "DOCS"]) do
    "OK"
  end

  ### END MISC ###

  ### STRING ###

  def interpret(["GET", key]) do
    StringServer.get(key)
  end

  def interpret(["SET", key, value]) do
    StringServer.set(key, value)
  end

  ### END STRING ###

  ### HASH ###

  def interpret(["HGET", hash_name, key]) do
    HashServer.hget(hash_name, key)
  end

  def interpret(["HGETALL", hash_name]) do
    HashServer.hgetall(hash_name)
  end

  def interpret(["HSET", hash_name | keypairs]) do
    HashServer.hset(hash_name, keypairs)
  end

  def interpret(["HLEN", hash_name]) do
    HashServer.hlen(hash_name)
  end

  def interpret(["HDEL", hash_name | keys]) do
    HashServer.hdel(hash_name, keys)
  end

  def interpret(["HKEYS", hash_name]) do
    HashServer.hkeys(hash_name)
  end

  def interpret(["HMGET", hash_name | keys]) do
    HashServer.hmget(hash_name, keys)
  end

  def interpret(["HEXISTS", hash_name, key]) do
    HashServer.hexists(hash_name, key)
  end

  def interpret(["HINCRBY", hash_name, key, increment]) do
    HashServer.hincrby(hash_name, key, increment)
  end

  ### END HASH ###
end
