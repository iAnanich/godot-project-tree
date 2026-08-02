# Performance contract

Version: 0.2.2

Scanning remains synchronous and bounded. Total acquisition cost is proportional to accepted GDScript bytes plus accepted text-scene bytes and graph construction. A selected folder does **not** reduce acquisition cost: v0.2.1 builds one bounded full-project index and then projects it to the selected display/export scope so outside context can be resolved.

Controls include maximum files, directories, script bytes, and scene bytes; symbolic links are disabled by default. Editor events are debounced so save/import bursts produce one scan. Timed rescanning is disabled by default. Search, scope projection, descendant queries, focus, and neighborhood isolation operate in memory and do not rescan.

`SnapshotScope` is linear in snapshot nodes/edges plus retained ancestor traversal. `GraphQuery` builds inheritance indexes and computes presentation sets synchronously. Descendant counts may approach quadratic work for a long inheritance chain because totals are calculated per node; this is acceptable for the current bounded editor graph but remains a measured optimization candidate rather than an assumed scalability guarantee.

The release performance gate analyzes 500 synthetic methods and builds a graph from 1,000 synthetic scripts against budgets of 5,000 ms and 6,000 ms. Per-engine observations belong in [the v0.2.2 compatibility matrix](validation/v0.2.2-compatibility-matrix.md); they are regression evidence for that fixture, not universal latency guarantees or cross-version rankings.

Background work and cancellation require a separate thread-safety and editor-lifecycle design.

Graph-off operation avoids GraphNode construction and rendering while retaining scan/validation/export costs. The release tests this behavioral boundary but does not claim universal memory or latency savings.
