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
  #
  # or: use a genserver per hashmap, and use the registry
  # to refer to the genserver

  alias Rex.HashServer
  alias Rex.StringServer

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
