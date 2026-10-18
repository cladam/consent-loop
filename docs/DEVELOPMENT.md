# ConsentLoop Development Plan and Log

## Purpose

This is the living execution plan and decision log for ConsentLoop. The product
contract remains in [PRD-ConsentLoop.md](./PRD-ConsentLoop.md); this document
records how the product is built, tested, verified, and adjusted over time.

Work proceeds one milestone at a time. Each milestone ends with a reflection and
a commit point before the next milestone begins.

## Working Method

Every milestone uses the same five-step loop:

1. **Plan** - define the behavior, constraints, smallest vertical slice, and
   acceptance evidence before changing code.
2. **Do** - implement only that slice, following existing hica library patterns.
3. **Test** - run focused automated tests that can falsify the implementation.
4. **Verify** - exercise the acceptance scenario through the public boundary and
   inspect externally visible output or persisted state.
5. **Reflect** - record what was learned, decisions made, remaining risks, and
   whether the next milestone should change.

Testing and verification are deliberately separate. Tests establish repeatable
correctness; verification confirms that the delivered behavior satisfies the
PRD from a caller's perspective.

### Milestone Gate

A milestone is complete only when:

- its acceptance criteria are met;
- focused tests pass;
- the public behavior has been verified;
- new decisions and risks are recorded in the log;
- documentation reflects the implementation; and
- the work is offered as a commit point before the next milestone starts.

## Ground Rules

Inherited (and lightly adapted) from the hedit journal:

0. **Small edits, frequent checks.** Every change ends with:
   - `hica check src/main.hc` clean (0 errors),
   - `hica build` succeeds,
   - `hica test tests/<feature>_test.hc` (and any new suites we add) all green.
1. **Regression tests before green.** Every milestone must add at least
   one test to a `tests/*_test.hc` file — failing first if we can arrange
   it, then passing.
2. **One runnable artefact per milestone.** Either a headless demo run
   via `hica run src/main.hc`, or an example under `examples/` (create
   the directory when we first need it).
3. **Docs updated in the same milestone.** `docs/PRD-ConsentLoop` and
   `README.md` are amended alongside the code — not "later".
4. **`hica fmt --check` and `hica analyse` on every artefact.** Every
   `.hc` file we ship (or edit) must pass:
   - `hica fmt --check <file>` → exit 0 (no formatting changes needed).
   - `hica analyse <file>` → clean report, no warnings/penalties beyond
     any sanctioned ones we've explicitly noted here.
5. **Clean the workspace.** `hica clean` will remove all generated .kk 
   files and binaries, use `hica clean --cache` to remove ~/.hica/stdlib.
   `hica clean --full` will also remove the .koka directory, the build cache and it will be needed as the std/cli .kki files will get out of sync. 
6. **Reflection is mandatory.** Before starting Mn+1 we write a
   Reflection section for Mn. If we skip it, we lose the pattern.
7. **Context-window discipline.** hica compiler internals are large — do
   NOT read them exhaustively. For each milestone, read only what the
   "Files to touch" section lists. Prefer `grep -n` over `read_file`
   when you only need to find a definition. If you find yourself over
   60% context and still exploring, **stop and commit what you have**
   with a Handoff Log entry.
8. **Follow the hica skill card when developing.** Read and follow .github/skills/hica/SKILL.md

## Technical Direction

### Libraries

- `http` supplies the server, router, response helpers, and in-process test
  client.
- `sqlite` stores proposals and their immutable revision history.
- `json` supplies a consistent API error format and machine-readable metadata
  where HML is not the response body.
- `hml` supplies `Hml`, `HmlNode`, `HElement`, `hml_parse`, navigation helpers,
  and `hml_pretty`.

### Initial Module Boundaries

The hica-registry project provides the baseline service shape:

```text
src/main.hc        thin process entry point and server startup
src/domain.hc      proposal model, invariants, and state transitions
src/proposal_hml.hc
                   HML decoding, validation, and canonical encoding
src/db.hc          schema and persistence operations
src/routes.hc      HTTP handlers and route table
tests/fixtures.hc  reusable HML and in-memory database fixtures
tests/test_*.hc    focused domain, persistence, and route tests
```

The domain layer must not depend on HTTP or SQLite. Routes orchestrate parsing,
domain operations, and persistence, while `main.hc` only wires the service.

### Persistence Model

Until a milestone reflection changes this decision:

- each accepted proposal version is stored as an immutable revision;
- canonical HML is the auditable revision payload;
- indexed columns hold the proposal id, semantic version, status, and timestamps
  needed for lookup and concurrency checks; and
- a transaction writes the new active version and its history record together.

This keeps the HML document authoritative without forcing every nested domain
value into relational tables prematurely.

## Milestone Roadmap

### M0 - Executable Service Foundation

**Outcome:** A minimal service can start and dispatch a tested health route.

**Plan**

- Confirm the installed hica and dependency versions.
- Establish the module and test layout.
- Add SQLite bootstrap against an in-memory database.
- Add `GET /health` through a separately testable route table.
- Define the API media types and JSON error envelope.

**Test**

- Database bootstrap is idempotent.
- In-process `GET /health` returns `200` with database status.
- `hica check` and the focused foundation tests pass.

**Verify**

- Start the service locally and call `/health` over HTTP.

**Exit criteria:** The process boundary, route boundary, and test harness work
without implementing proposal behavior.

**Status:** Ready

### M1 - HML Proposal Codec and Validation

**Outcome:** Raw HML can be converted into a validated domain proposal and back
into stable canonical HML.

**Plan**

- Model proposal identity, semantic version, lifecycle status, participants,
  amendments, references, and revision events as hica types.
- Parse with `hml_parse` and navigate with the public `hml` accessors.
- Validate required elements, attributes, value types, uniqueness, and comfort
  level range.
- Emit through the HML data model and `hml_pretty`.
- Preserve meaningful body text and namespace information.

**Test**

- Parse the canonical PRD example.
- Reject malformed HML and structurally invalid proposals separately.
- Reject duplicate participants and levels outside `0..3`.
- Round-trip a valid proposal through decode and canonical encode.

**Verify**

- Compare canonical output with an approved fixture and parse it again.

**Exit criteria:** Valid proposal HML round-trips without HTTP or database code.

**Files touched**

- `src/domain.hc`
- `src/proposal_hml.hc`
- `tests/fixtures.hc`
- `tests/proposal_codec_test.hc`
- `examples/proposal_codec.hc`
- `docs/PRD-ConsentLoop.md`
- `README.md`

**Status:** Complete

### M2 - Immutable Proposal Store

**Outcome:** Proposals and their complete revision chain can be stored and read
atomically.

**Plan**

- Add proposal and revision tables with foreign keys and uniqueness constraints.
- Store canonical HML for every revision.
- Track the active revision without mutating historical payloads.
- Add repository functions for create, fetch active, and fetch history.

**Test**

- Use a fresh in-memory SQLite database per test.
- Create and retrieve a proposal with byte-stable canonical HML.
- Reject duplicate proposal ids and duplicate versions.
- Prove failed revision writes do not change the active revision.

**Verify**

- Inspect the persisted active proposal and ordered history after two revisions.

**Exit criteria:** Persistence invariants hold independently of HTTP handlers.

**Status:** Planned

### M3 - Proposal Submission API

**Outcome:** `POST /v1/proposals/submit` accepts raw HML, initializes a proposal,
and persists canonical version `1.0`.

**Plan**

- Add the submission handler and route.
- Enforce initial version and lifecycle invariants in the domain layer.
- Return canonical HML on success and structured JSON errors on failure.
- Define duplicate submission behavior explicitly.

**Test**

- Valid submission returns the expected status code and canonical HML.
- Invalid syntax and invalid domain structure return distinct `400` errors.
- Duplicate id returns `409` without adding a revision.

**Verify**

- Submit the PRD fixture through the in-process client, then fetch the stored row.
- Repeat once against the running HTTP server.

**Exit criteria:** The first PRD endpoint works end to end.

**Status:** Planned

### M4 - Comfort Evaluation and Refinement

**Outcome:** Evaluation deterministically moves proposals to `passed` or
`refinement` according to participant comfort levels.

**Plan**

- Encode legal lifecycle transitions as pure domain functions.
- Require a concrete amendment for every Level 0 or Level 1 response.
- Move to `passed` only when every participant is Level 2 or Level 3.
- Move to `refinement` when any valid Level 0 or Level 1 response exists.
- Persist each accepted transition as a revision.

**Test**

- Cover all-comfortable, hesitant, blocked, missing-amendment, and mixed cases.
- Reject illegal status changes and stale source versions.
- Prove evaluation is deterministic for equivalent participant input.

**Verify**

- Exercise both branches through `POST /v1/proposals/evaluate` and inspect the
  returned HML and revision history.

**Exit criteria:** The central consent decision rule is complete and auditable.

**Status:** Planned

### M5 - Amendment Resolution and Semantic Versioning

**Outcome:** Amendment adoption and directional shifts produce the correct
version, participant state, and history event.

**Plan**

- Adopt exact amendment wording as a minor version bump.
- Move the originating objector to Level 2 after adoption.
- Represent a directional rewrite as a major version bump.
- Reset all comfort levels and restart review after a major bump.
- Reject ambiguous, already resolved, or wrong-version amendments.

**Test**

- Cover minor increments, major increments, reset behavior, and history events.
- Test boundaries such as `1.9 -> 1.10` and `1.10 -> 2.0`.
- Prove each resolution creates exactly one immutable revision.

**Verify**

- Run one proposal through hesitant, adopted, and passed states.
- Run another through blocked and directionally rewritten states.

**Exit criteria:** Both resolution paths in the PRD work end to end.

**Status:** Planned

### M6 - Retrieval and Audit Trail

**Outcome:** `GET /v1/proposals/{id}` returns the active proposal and complete,
ordered revision history.

**Plan**

- Add the retrieval route and not-found behavior.
- Define whether history is embedded in canonical HML or represented by an API
  envelope without duplicating sources of truth.
- Ensure ordering and timestamps are stable and explicit.

**Test**

- Retrieve proposals with zero, one, and multiple transitions.
- Return `404` for an unknown id.
- Verify history order and active-version consistency.

**Verify**

- Retrieve both M5 scenarios and reconstruct why each active version exists.

**Exit criteria:** A caller can audit every decision from submission to outcome.

**Status:** Planned

### M7 - Hardening and Release Readiness

**Outcome:** The v1 service has explicit operational limits and a repeatable
release check.

**Plan**

- Resolve authentication and participant identity requirements.
- Add request-size limits, transaction contention behavior, and concurrency
  protection for stale evaluations.
- Define clock handling and cooling-period enforcement.
- Add migration, backup, logging, and configuration documentation.
- Pin dependency versions for reproducible builds.

**Test**

- Run the complete suite from a clean database.
- Cover stale writes, malformed large requests, and database failures.
- Add an HTTP integration smoke test for all three PRD endpoints.

**Verify**

- Execute a clean local setup and the complete decision lifecycle using only the
  documented API.

**Exit criteria:** The release checklist passes and remaining limitations are
documented as explicit non-goals or follow-up work.

**Status:** Planned

## Product Questions to Resolve

These questions should be answered at the milestone where they first control
behavior, rather than silently encoded as implementation assumptions:

1. What event moves a proposal from `submission` to `review`?
2. Who is the author at the API boundary, and how is identity established?
3. Is the cooling period enforced by wall-clock time in v1, and what occurs when
   it expires?
4. How does the request distinguish amendment adoption from a directional
   rewrite?
5. What exactly belongs to the hidden impact evaluation beyond the explicit
   comfort-level rules in the PRD?
6. How are concurrent evaluations of the same active version rejected or made
   idempotent?
7. Should the API use `application/hml`, `text/hml`, or a documented temporary
   content type?

## Development Log

Entries are append-only. Corrections should be added as new information rather
than rewriting the historical reasoning.

### 2026-10-17 - Roadmap and Reference Architecture

**Milestone:** Planning for M0

**Plan**

- Read the PRD and current ConsentLoop scaffold.
- Inspect hica-registry for its HTTP, SQLite, and route-test patterns.
- Confirm the HML dependency and its public API using x2hml and the library
  source.
- Convert the findings into gated vertical milestones.

**Do**

- Confirmed `http`, `sqlite`, `json`, and `hml` in `hica.hml`.
- Selected the hica-registry structure: thin entry point, separate routes and
  database modules, in-process route tests, and in-memory SQLite fixtures.
- Confirmed the HML barrel exports parsing, typed nodes, accessors, and display.
- Defined seven implementation milestones after the initial foundation.

**Test**

- Checked the dependency manifest directly.
- Traced x2hml's use of `Hml`, `HmlNode`, `HElement`, and HML pretty-printing.
- Traced the HML library's `hml_parse`, `hml_get`, `hml_elem`, `hml_attr`,
  extractors, and `hml_pretty` APIs.

**Verify**

- Mapped every PRD endpoint to a milestone.
- Mapped both semantic-version resolution paths and all four lifecycle states to
  explicit test and verification work.

**Reflect**

- HML parsing is an available dependency, not a feasibility risk.
- The first implementation step should establish the executable service and test
  boundaries before adding proposal behavior.
- The largest remaining risks are unresolved product semantics, especially
  identity, cooling-period behavior, impact evaluation, and concurrent updates.

**Result:** M0 is ready to begin.

### 2026-10-18 - Typed Proposal HML Codec

**Milestone:** M1

**Plan**

- Model proposals, participants, amendments, references, and revisions as hica
   domain types without HTTP or SQLite dependencies.
- Decode raw HML into the model with distinct syntax and validation errors.
- Enforce required fields, unique participants, comfort range, and mandatory
   amendments for Level 0 and Level 1.
- Emit deterministic canonical HML and prove round-trip stability.

**Do**

- Added the domain model in `src/domain.hc`.
- Added typed decoding, validation, and canonical emission in
   `src/proposal_hml.hc`.
- Added an in-source proposal fixture because test-mode file reads are not used.
- Added `#text: amendment` to the proposal document contract so raw amendment
   prose is valid HML.
- Added a runnable codec example under `examples/`.

**Test**

- Started with a red canonical decode test, then added red-green tests for the
   mandatory-amendment invariant and canonical encoding.
- `hica test tests/proposal_codec_test.hc`: 7/7 tests passed.
- Covered canonical decode, syntax-error classification, missing title,
   duplicate participants, invalid comfort levels, mandatory amendments, and
   byte-stable round trips.
- `hica fmt --check` passed for all five Hica artifacts.
- `hica analyse` reported no warnings or penalties and a 100/100 quality index
   for all five Hica artifacts.
- `hica check src/main.hc` and `hica build` passed.

**Verify**

- `hica run examples/proposal_codec.hc` completed successfully.
- The example decoded raw HML and emitted canonical output beginning with the
   HML version, amendment text directive, and decision namespace.

**Reflect**

- The HML AST and public navigation API are sufficient for a typed domain codec;
   no custom parser is needed.
- Raw prose in non-default text elements must be declared with `#text`, which is
   now part of the proposal format.
- Hica test mode monomorphizes unannotated generic top-level helpers. Constructing
   typed validation errors at each concrete return site avoids that ambiguity.
- The codec is intentionally independent of the service foundation. M0 remains
   deferred and must be completed before API milestone M3.

**Result:** Complete. Pause for a commit before beginning another milestone.

## Log Entry Template

```markdown
### YYYY-MM-DD - Short outcome

**Milestone:** Mx

**Plan**
- Intended behavior and evidence.

**Do**
- Changes made and important decisions.

**Test**
- Automated checks and results.

**Verify**
- Public acceptance scenario and observed result.

**Reflect**
- Learning, risks, and roadmap changes.

**Result:** Complete, continue, revise, or blocked.
```