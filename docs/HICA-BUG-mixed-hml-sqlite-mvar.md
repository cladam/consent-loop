# Hica Bug: Mixed HML and SQLite Executable Blocks in Koka

## Environment

- hica `0.49.15`
- Koka `3.2.3`
- macOS arm64

## Symptom

An optimized executable that imports the typed proposal store, constructs a
`Proposal`, and calls both `create_proposal` and `append_revision` passes Hica
checking but blocks during Koka compilation:

```text
thread blocked indefinitely in an MVar operation

error: koka failed with exit code 256
aborted: not running stale executable because compilation failed
```

`hica clean --full` followed by `hica --version` does not change the result.

## Reproduction Shape

```hica
import "../src/db"
import "../src/domain"
import "../src/proposal_store"
import "sqlite"

fun main() {
  let db = unwrap(sqlite_open(":memory:"))
  let _ = init_db(db)
  let first = make_proposal("1.0", Submission)
  let second = Proposal { ...first, version: "1.1", status: Review }
  let _ = create_proposal(db, first)
  let _ = append_revision(db, second)
}
```

## Control Cases

- `hica test tests/proposal_store_test.hc` compiles and passes all four tests
  using the same typed operations.
- `hica build` succeeds while the server imports only primitive `db.hc`.
- An executable using `create_stored_proposal` and `append_stored_revision`
  directly compiles and runs.
- Replacing `foreach` with recursion in the demo does not resolve the block.

## Impact

M2 storage is testable and the primitive persistence executable works, but M3
will combine HML decoding and SQLite inside the HTTP server. This compiler block
must be resolved or disproved against that concrete route before M3 can pass its
executable acceptance gate.