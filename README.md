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

Scenarios run sequentially against one disposable database. CI runs both suites.
Choreo writes its reports under the ignored `reports/` directory. The existing
`health_integration.sh` and `submission_integration.sh` commands run the
corresponding Choreo suite through the same lifecycle runner.

Syntax can be checked without starting the service:

```sh
choreo validate --file tests/health.chor
choreo validate --file tests/submission.chor
```

Coverage follows the implemented milestones M0-M3. Evaluation, amendment
resolution/version bumps, and proposal retrieval remain planned behavior, not
passing acceptance claims; add their executable scenarios as those APIs land.

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
