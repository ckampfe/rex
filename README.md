# Rex

A little crappy implementation of Redis

[![Elixir CI](https://github.com/ckampfe/rex/actions/workflows/elixir.yml/badge.svg)](https://github.com/ckampfe/rex/actions/workflows/elixir.yml)

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

#### Strings

- GET
- SET

#### Hashes

- HGET
- HSET
- HGETALL
- HLEN
- HDEL
- HKEYS
- HMGET
- HEXISTS
- HINCRBY

#### Lists

- LPUSH
- RPUSH
- LPOP
- RPOP
- LLEN
- BLPOP
- BRPOP

#### Sets

- SADD
- SMEMBERS
- SISMEMBER

#### Misc

- PING

## design

Instread, we use GenServers, partitioning state across them to allow concurrent operations.

Strings (`GET`, `SET`) are partitioned across N servers where N = `System.schedulers_online()`.

Each hash and list gets its own server, so operations on hash/list `a` and hash/list `b` happen concurrently.

Uses [Thousand Island](https://hexdocs.pm/thousand_island/ThousandIsland.html) for TCP connection pooling.
