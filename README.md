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
