# Rex

A little crappy implementation of Redis

## Run

start the server:
```sh
$ iex -S mix
```

connect to it:
```sh
$ redis-cli
```

## supported operations

- PING
- GET
- SET
- HGET
- HSET
- HGETALL
- HLEN
- HDEL
- HKEYS
- HMGET
- HEXISTS
- HINCRBY

## design

Does not use ETS as ETS does not have transactions, so you cannot, for example, read a key and then write back to that key and have any guarantee that the value at that key was not mutated before your write. This is needed because many Redis operations require the ability to read a key before writing to it. ETS also does not have "compare and swap" semantics that would allow you to build this yourself.

Instread, we use GenServers, partitioning state across them to allow concurrent operations.

Strings (`GET`, `SET`) are partitioned across N servers where N = `System.schedulers_online()`.

Each hash gets its own server, so operations on hash `a` and hash `b` happen concurrently.

Uses [Thousand Island](https://hexdocs.pm/thousand_island/ThousandIsland.html) for TCP connection pooling.
