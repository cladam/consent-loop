# ConsentLoop

ConsentLoop is a lightweight, friction-first decision engine designed to eliminate the toxic "winner-loser" dynamics of traditional majority-rule voting.

## Documentation

- [Product requirements](docs/PRD-ConsentLoop.md)
- [Development plan and log](docs/DEVELOPMENT.md)

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
hica run examples/proposal_store.hc
```
