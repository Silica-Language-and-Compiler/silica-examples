# route-planner

Shortest routes and a minimum spanning tree over a 16-city road network, using the standard library's data structures:

- `graph_weighted_undirected`: the live weighted undirected graph (`add_edge`, `weighted_neighbors`). Road weights are lengths in tens of kilometres.
- `brodal_okasaki_priority`: the PriorityQueue implementation (`push_priority`, `pop_priority`).

Dijkstra and Prim are one recursive best-first search (`search`/`visit` in `main.silica`). Dijkstra queues total distance; Prim queues single-road length. There are no loops. A settled city is packed into one `int64` in a `List[int64, mem(normal)]`: `priority * 10000 + city * 100 + came_from`.

The graph and queue types are written out in full in the signatures. Silica has no generics, and the library's own trials spell them out the same way. The stdlib structures are used as is; no hand-rolled fallback was needed.

## Run

```console
$ silica run route-planner
```

`main` returns `:ok`, so the exit status is 2. The CLI downloads the standard library on first use.

## The network (city: id)

Lisbon 0, Madrid 1, Barcelona 2, Lyon 3, Paris 4, Brussels 5, Amsterdam 6, Cologne 7, Berlin 8, Munich 9, Zurich 10, Milan 11, Rome 12, Vienna 13, Prague 14, Warsaw 15.

Roads: Lisbon-Madrid 62, Madrid-Barcelona 62, Madrid-Paris 130, Barcelona-Lyon 64, Lyon-Paris 46, Lyon-Zurich 41, Lyon-Milan 44, Paris-Brussels 31, Brussels-Amsterdam 21, Brussels-Cologne 21, Amsterdam-Cologne 25, Amsterdam-Berlin 65, Cologne-Berlin 57, Cologne-Munich 58, Zurich-Munich 31, Zurich-Milan 28, Milan-Rome 57, Rome-Munich 70, Munich-Vienna 40, Munich-Prague 38, Berlin-Prague 28, Prague-Vienna 25, Berlin-Warsaw 57, Prague-Warsaw 52, Vienna-Warsaw 68.

## Output

```
shortest routes:
Lisbon -> Madrid -> Barcelona -> Lyon -> Zurich -> Munich -> Prague -> Warsaw (distance 350)
Amsterdam -> Cologne -> Munich -> Rome (distance 153)
Barcelona -> Lyon -> Zurich -> Munich -> Vienna (distance 176)
Paris -> Brussels -> Cologne -> Berlin -> Prague (distance 137)
Lisbon -> Madrid -> Barcelona -> Lyon -> Milan -> Rome (distance 289)
minimum spanning tree: 15 roads, total weight 607
```

Each shortest path is unique, and 607 is the Kruskal and Prim total (15 roads for 16 cities).
