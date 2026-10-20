# Performance

How import time and memory grow with the number of Cartons and the size of the bundle, measured with [`bench/scale.rb`](../bench/scale.rb). Each measurement runs in a fresh Ruby process, since imports last for the life of the process.

```sh
bundle exec rake bench   # or: ruby bench/scale.rb
```

## Results

Ruby 4.0.7 on an Apple M5 Pro (virtualized, 16 GB), October 2026, median of three runs. Absolute numbers depend on the machine; the shape is the point.

### Plain Cartons

One-file Cartons imported with `import_relative`, against requiring the same files without Carton:

| Cartons | require (ms) | import (ms) | per import (ms) | memory per Carton (MB) |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 0.2 | 60.7 | 60.7 | 2.47 |
| 10 | 0.7 | 587.6 | 58.8 | 2.4 |
| 50 | 3.0 | 3017.0 | 60.3 | 2.34 |
| 200 | 11.7 | 12335.0 | 61.7 | 2.36 |

### Gem Cartons

Ten path gems imported by name under `bundler/setup`, in bundles of growing size:

| Locked gems | import (ms) | per import (ms) | memory per Carton (MB) |
| ---: | ---: | ---: | ---: |
| 11 | 1949.9 | 195.0 | 5.99 |
| 51 | 1994.6 | 199.5 | 6.91 |
| 201 | 2807.7 | 280.8 | 8.11 |

### Rails examples

Whole-process wall time, including Ruby's own boot, for the earlier smoke examples. These Rails samples predate the Engine/CLI expansion; the current Rails-in-Cartons demo also prepares a temporary database in another process, so rerun the benchmark before comparing current startup times:

| Example | process wall time (ms) |
| --- | ---: |
| rails_in_main | 1497.5 |
| rails_in_cartons | 2467.2 |

## Where the time goes

Each import costs about the same no matter how many came before, so cost grows linearly with the number of Cartons. Measured separately, per Box:

| Step | Time (ms) | Memory (MB) |
| --- | ---: | ---: |
| `Ruby::Box.new` | 55 | 2.2 |
| Loading Carton itself into the Box | 1.4 | 0.15 |
| First `Gem::Specification.from_yaml`, which loads Psych (Gem Cartons only) | 86 | |
| Each further spec rebuilt from YAML (Gem Cartons only) | 0.15 | |
| `require 'bundler'` to restrict the Box to the lockfile (Gem Cartons only) | 9 | 2.4 |

- **Creating a Box is the floor.** Ruby copies its builtin classes into every new Box, about 55 ms and 2.2 MB on this machine. Carton adds little on top of it. That makes Carton suited to gem-sized or domain-sized units, tens of Cartons rather than hundreds. 200 one-file Cartons take 12 seconds to boot.
- **Gem Cartons pay for Psych.** Carton rebuilds the importer's gem specs in each new Box with a YAML round trip, and the first one loads Psych into that Box. That is almost half of a Gem Carton's cost. The bundle's size matters much less: 190 more locked gems add about 85 ms per import.
- **Rails in Cartons** booted about a second slower in this snapshot than Rails in the Main Box: four Carton Boxes, and Rails' gems activated in the framework Box.

[todo.md](todo.md) tracks rebuilding specs without YAML and reporting Box creation cost upstream.

## Shared Gems experiment

The [standalone Shared Gems prototype](../spikes/shared_gems/results.md#performance) compares independent loads, userspace installation, the unsupported Master prelude, and existing plain Carton imports at 1, 5, 10, 25 and 50 Boxes. Its raw JSON records time, retained RSS, source compilation, feature loads and installation counts. These are exploratory single samples with TracePoint instrumentation, separate from the median measurements above. They demonstrate the cost opportunity for an explicit Active Support sharing contract; normal gem activation and arbitrary loading remain unsupported.
