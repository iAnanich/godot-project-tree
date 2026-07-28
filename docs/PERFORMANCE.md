# Performance contract

## User-facing expectation

Scanning is manual by default. A bounded project should complete without freezing the editor indefinitely or exhausting memory. The current implementation is synchronous, so the primary controls are explicit scan limits and predictable algorithmic behavior rather than background execution.

## Limits

Default limits are configurable in `default_settings.tres`:

- 10,000 scanned files;
- 20,000 scanned directories;
- 4 MiB per script;
- symbolic links skipped.

Reaching a limit produces a warning and a marked partial result. It is not silently treated as complete.

## Reproducible gate

`tests/performance_runner.gd` exercises two synthetic but reviewable shapes:

1. 500 typed method declarations through the source analyzer.
2. 1,000 scripts in a deep inheritance chain through the graph builder.

The gate verifies output completeness and reports elapsed milliseconds as `SDI_PERFORMANCE` JSON. Budgets are intentionally loose enough to tolerate shared CI and old supplied engines; they are regression tripwires, not product latency promises.

```sh
godot --headless --path . --script tests/performance_runner.gd
```

Record results per engine in `docs/VALIDATION.md`. A passing microbenchmark does not establish editor responsiveness for all real projects. Representative large-project profiling and cancellable/background scanning remain future work.

## Executed 0.1.6 results

Each supplied Linux engine completed the same fixture with 500 analyzed methods, 1,000 script records, 1,002 graph nodes, and 1,001 graph edges:

| Godot | Analyzer | Graph builder |
|---|---:|---:|
| 4.3 | 233.52 ms | 955.21 ms |
| 4.4.1 | 230.38 ms | 893.69 ms |
| 4.5.2 | 225.91 ms | 782.08 ms |
| 4.6.3 | 223.73 ms | 778.18 ms |
| 4.7 | 238.25 ms | 773.34 ms |

All results are below the deliberately loose 5,000 ms analyzer and 6,000 ms graph budgets. These values were measured in the supplied execution environment and are regression evidence, not portable latency guarantees.
