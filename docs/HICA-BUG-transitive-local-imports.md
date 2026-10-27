# Hica Bug: Transitive Local Imports Omitted from Koka Build

## Environment

- hica `0.49.15`
- Koka `3.2.3`
- macOS arm64

## Symptom

An entry file imports `proposal_store`, which imports `proposal_hml`, but hica
does not add the transitive local `proposal_hml` module to the Koka build list.
Koka first reports the missing module internally and then reports its worker
failure as an MVar block:

```text
internal error: cannot find ("proposal_hml","","")
thread blocked indefinitely in an MVar operation

error: koka failed with exit code 256
aborted: not running stale executable because compilation failed
```

The MVar message is a secondary Koka symptom, not the cause. Optimization,
SQLite, HML, and stale caches are not responsible.

## Cause

hica drops transitive local imports when constructing the Koka module list:

```text
entry file
  -> proposal_store
       -> proposal_hml
            -> hml
```

`import-sigs-only` discovers enough of this graph for hica type-checking, but
the build step does not add every discovered local `.hc` module to Koka's input
modules.

`hica test tests/proposal_store_test.hc` masks the defect because the test file
imports `proposal_hml` directly as well as `proposal_store`.

## Reproduction Shape

```hica
import "../src/db"
import "../src/domain"
import "../src/proposal_store"
import "sqlite"

fun main() {
  let db = unwrap(sqlite_open(":memory:"))
  let _ = init_db(db)
  let proposal = make_proposal()
  let _ = create_proposal(db, proposal)
  println("ok")
}
```

The entry file checks successfully but fails during Koka compilation. Adding
this direct import makes the same program compile and print `ok`:

```hica
import "../src/proposal_hml"
```

## ConsentLoop Workaround

Until hica builds the complete transitive local module graph, every executable
entry module must directly import each local module in its dependency chain.
When M3 wires the typed proposal store into HTTP:

- `src/main.hc` must directly import `./proposal_hml`;
- `src/routes.hc` must directly import `./proposal_hml`; and
- route tests should retain their direct codec import rather than relying on a
  transitive import.

## Module Name Collision

A separate issue was found while reproducing the failure:
`examples/proposal_store.hc` shared its module basename with
`src/proposal_store.hc`. Koka's include-path search can resolve one module to the
other and produce unrelated missing-identifier errors. The example is therefore
named `examples/proposal_demo.hc`.

hica should warn when two modules on its include paths share a basename.

## Expected Hica Fix

1. Add transitive local imports from every imported `.hc` file to the Koka
   module list, using the graph already discovered for `import-sigs-only`.
2. Detect duplicate module basenames across include paths and report a clear
   diagnostic before invoking Koka.

The separate Koka `-O2` recursive-ADT issue remains unrelated and open.