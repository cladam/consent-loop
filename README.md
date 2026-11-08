# ConsentLoop

ConsentLoop is a lightweight, friction-first decision engine designed to eliminate the toxic "winner-loser" dynamics of traditional majority-rule voting.

## Documentation

- [Product requirements](docs/PRD-ConsentLoop.md)
- [Development plan and log](docs/DEVELOPMENT.md)

## Executable Acceptance Specifications

[Choreo](https://github.com/cladam/choreo) is the BDD acceptance-test runner:
the specification is the executable. The `.chor` scenarios call the real HTTP
API and check observable behavior; hica unit tests remain the focused checks for
the codec, domain, persistence, and in-process routes.

Install Choreo 0.15.0 (requires Rust/Cargo), then run:

```sh
cargo install --locked choreo --version 0.15.0
make test-acceptance
```

The runner also requires `hica`, `curl`, and the `sqlite3` CLI. It builds the
service once, starts it with a fresh temporary SQLite database, waits for
readiness, and stops the process and removes temporary files on exit. Port 8080
must be free; the runner refuses to test against an existing listener.

- [Service readiness](tests/health.chor) specifies HTTP and SQLite health.
- [Proposal submission](tests/submission.chor) specifies canonical version `1.0`,
  initial history, persistence, duplicate protection, malformed/invalid HML,
  participant uniqueness, comfort-level bounds, and mandatory amendments for
  dissent. Rejected requests must leave the entire stored audit trail unchanged.
- [Comfort evaluation](tests/evaluation.chor) specifies transition to `passed` or
  `refinement`, explicit review window entry, same-version immutable storage,
  stale version checks, and illegal transition rejection.
- [Amendment resolution](tests/resolution.chor) specifies minor version bumps for
  adopted amendments with automatic transition to consent, major version bumps for
  directional shifts with review restart, and rejection of wrong-version or
  already resolved amendments.

Scenarios run sequentially against one disposable database. CI runs the suites.
Choreo writes its reports under the ignored `reports/` directory. The existing
`health_integration.sh` and `submission_integration.sh` commands run the
corresponding Choreo suite through the same lifecycle runner.

Syntax can be checked without starting the service:

```sh
choreo validate --file tests/health.chor
choreo validate --file tests/submission.chor
choreo validate --file tests/evaluation.chor
choreo validate --file tests/resolution.chor
```

Coverage follows the implemented milestones M0-M5. Proposal retrieval (M6)
remains planned behavior, not passing acceptance claims; add executable
scenarios as that API lands.

## Proposal Codec

Milestone M1 provides typed decoding, validation, and canonical HML emission for
ConsentLoop proposals.

```sh
hica test tests/proposal_codec_test.hc
hica run examples/proposal_codec.hc
```

## Service Foundation

Build and run the native service:

```sh
hica build
CONSENT_LOOP_DB_PATH=./consent-loop.db ./src/main
curl http://localhost:8080/health
```

Run the foundation and live health checks:

```sh
hica test tests/foundation_test.hc
./tests/health_integration.sh
```

The Docker image targets `linux/amd64` for deployment. On other architectures,
use the native workflow above; CI builds and smoke-tests the x86-64 image.

## Immutable Proposal Store

Milestone M2 stores canonical proposal revisions in SQLite while tracking the
active version separately from immutable history.

```sh
hica test tests/proposal_store_test.hc
hica run examples/proposal_demo.hc
```

## Proposal Submission API

Milestone M3 accepts raw proposal HML at `POST /v1/proposals/submit`, normalizes
it to canonical version `1.0` in `submission`, and stores its initial immutable
revision. Successful requests return `201 application/hml`; duplicate proposal
ids return a structured `409` JSON error.

```sh
hica test tests/submission_test.hc
./tests/submission_integration.sh
```

## Comfort Evaluation and Refinement

Milestone M4 evaluates participant comfort levels at `POST /v1/proposals/evaluate`.
Moving to `passed` requires all participants at Level 2 or 3; any valid Level 0 or 1
response with an actionable amendment moves the proposal to `refinement`. Proposals
can also explicitly enter `review`. Same-version transitions are stored immutably as
distinct revisions in SQLite and tracked by `active_revision_id`.

```sh
hica test tests/comfort_evaluation_test.hc
hica test tests/evaluation_test.hc
hica run examples/comfort_evaluation.hc
```



## Amendment Resolution and Semantic Versioning

Milestone M5 resolves amendments via `POST /v1/proposals/evaluate`:
- **Amendment adoption** increments the minor version (`1.0` -> `1.1`), incorporates
  the amendment wording, transitions the objector automatically to Level 2 (Consent),
  and appends an `@history` entry with event `amendment-adopted`.
- **Directional shifts** increment the major version (`1.x` -> `2.0`), reset all
  participant comfort levels to unvoted (leaving the proposer at Level 3), restart
  the cooling review window (`review` status), and append an `@history` entry with
  event `directional-shift`.
- Invalid attempts (wrong target versions, already resolved amendments, ambiguous
  concurrent adoptions) are rejected with structured JSON errors leaving the audit
  trail unchanged.

```sh
hica test tests/comfort_evaluation_test.hc
hica test tests/evaluation_test.hc
hica run examples/amendment_resolution.hc
```
