# web-server

A minimal HTTP server in Silica. It listens on `127.0.0.1:5173` and answers every request with `Hello Web Server`.

```console
$ silica run silica-examples/web-server
    Building libsilica_sockets.a
   Compiling web-server (3 modules) with silica-999921-macos-applesilicon
  Assembling web-server
     Linking web-server
    Finished silica-examples/web-server/.silica-build/web-server/web-server
     Running silica-examples/web-server/.silica-build/web-server/web-server
Hello Web Server listening on 127.0.0.1, port:5173
```

In another terminal:

```console
$ curl http://localhost:5173
Hello Web Server
```

Stop it with Ctrl-C.

The server uses the standard library's TCP carrier. The `silica` CLI downloads the standard library on first use, then builds the C socket wrappers (`libsilica_sockets.a`) into `.silica-build/`, so there is nothing to set up. To build against a local Silica checkout instead, set `SILICA_STDLIB=<checkout>/compiler/stdlib`.

## How it works

`dangerous_web_server.silica` uses the standard library's `(:tcp)` carrier (`dangerous_tcp_carrier`). The carrier is a dangerous actor over the C socket wrappers in `compiler/stdlib/net/silica_sockets.c`.

1. `main` spawns a carrier and opens it with `"listen:5173"`. The listener binds loopback only.
2. For each connection, the listener sends `(:accepted, conn, peer)` to the `server` actor, and `server` spawns a `session` to open that connection.
3. The `session` grants one receive credit. On the first `:rx`, it sends a fixed `HTTP/1.1 200` response and `:close`. On `:link_down`, it stops.

The module's name starts with `dangerous_` because it depends on FFI wrappers. See the dangerous FFI security model in the Silica repository.

## Notes

- While the server runs, it prints `[silica] root actor exited (no supervisor)` twice per request. These lines come from the connection's carrier and session ending normally.
- The server answers once per connection and does not parse the request. Every path and method gets the same response.
- It is plain TCP with no TLS, reachable only from this machine. To accept connections from other machines, change the address to `"listen:any:5173"`.
