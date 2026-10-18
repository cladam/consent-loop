# Product Requirement Document (PRD): ConsentLoop Decision Engine

## 1. Executive Summary & Vision

**ConsentLoop** is a lightweight, friction-first decision engine designed to eliminate the toxic "winner-loser" dynamics of traditional majority-rule voting. By treating dissent not as a veto, but as a **diagnostic tool** to improve a proposal, ConsentLoop shifts groups from adversarial debate to collective refinement.

The tool operates on an egalitarian, peer-to-peer basis without unequal roles or permissions. Proposals are represented as living **HML** documents that evolve through semantic versioning (`v1.0` $\rightarrow$ `v1.x` / `v2.0`) as amendments are adopted or directions are refined.

---

## 2. Core Design Principles

* **Consent Over Consensus:** Decisions require zero unaddressed safety objections—not universal adoration.
* **Egalitarian & Flat:** All participants hold equal standing. There are no title-based approvers or veto privileges.
* **Mandatory Amendment on Dissent:** Disagreement (Levels 0 or 1) cannot be expressed as a silent downvote; it must be accompanied by an actionable text amendment.
* **Traceable Semantic Versioning:** Proposals evolve like software code. Adopted amendments or directional shifts trigger clear version bumps (`v1.1`, `v2.0`).
* **Hidden Impact Evaluation:** Impact and risk calculation are handled internally by backend evaluation logic, keeping the input domain language (HML) clean and unburdened by arbitrary score inputs.

---

## 3. Decision Lifecycle & State Machine

```
[Submission (v1.0)] ──> [Review & Comfort Check] 
                               │
            ┌──────────────────┴──────────────────┐
            ▼                                     ▼
     (All Levels 2-3)                     (Any Level 0-1)
            │                                     │
            ▼                                     ▼
      [Passed State]                      [Refinement State]
                                                  │
                                                  ▼
                                      [Mandatory Amendment]
                                                  │
                                  ┌───────────────┴───────────────┐
                                  ▼                               ▼
                           (Author Adopts)                (Author Modifies)
                                  │                               │
                                  ▼                               ▼
                          [Minor Bump (v1.x)]            [Major Bump (v2.0)]

```

### States

1. **`submission`**: Initial draft published as `v1.0`. Contains the problem context, proposed direction, and non-goals.
2. **`review`**: Active cooling window where participants read the proposal and record their comfort levels.
3. **`refinement`**: Triggered automatically if any participant selects Level 0 or Level 1. Discussion is restricted exclusively to active amendments.
4. **`passed`**: Final state reached when all participants reach Level 2 or Level 3 for the active version.

---

## 4. Participant Comfort Levels & Voting Mechanics

Participants register one of four qualitative comfort states:

| Comfort Level | Name | System Behavior & Requirements |
| --- | --- | --- |
| **Level 3** | Champion | Full endorsement; willing to help drive execution. |
| **Level 2** | Consent | Safe enough to try; no active objections. |
| **Level 1** | Hesitant | Reservations present. **Mandatory:** Must attach a concrete text amendment. |
| **Level 0** | Block | Core boundary violation. **Mandatory:** Must attach a concrete text amendment explaining the blocker. |

---

## 5. Resolution & Semantic Versioning Rules

When an amendment is attached, the author resolves it via one of two paths:

* **Minor Version Bump (`v1.x`) — *Amendment Adoption***
* The author incorporates the amendment's exact wording into the proposal text.
* The version increments in the minor slot (`v1.0` $\rightarrow$ `v1.1`).
* The objector's status automatically transitions to **Level 2 (Consent)**.


* **Major Version Bump (`v2.0`) — *Directional Shift***
* The author rejects the specific amendment but rewrites the core direction to address the underlying risk.
* The version increments in the major slot (`v1.1` $\rightarrow$ `v2.0`).
* All participant comfort levels reset, and a new cooling review window begins for the revised document.



---

## 6. System Architecture & HML Domain Schema

The engine exposes an **HTTP API** written in `hica` that receives raw **HML** payloads, validates document structure, executes state machine transitions, and calculates internal impact logic.

### Canonical HML Document Structure

```hica
#hml 0.3
#text: amendment
#namespace decision: "https://hica.dev/schemas/decision/v1"

@proposal(id: "PROP-042", version: "1.1", status: "refinement") {
    title: "Migrating core microservices to a trunk-based monorepo structure"
    created: 2026-06-06T10:00:00Z
    cooling-period: 24h
    
    @body {
        We are currently spending too much coordination overhead across siloed repositories. 
        This proposal evaluates moving our backend services into a single unified repository.
    }

    // Flat Participant Pool — Equal Standing
    @participants {
        @participant(user: "alex", level: 3)
        @participant(user: "sofia", level: 1) {
            @amendment(target-version: "1.1", status: "adopted") {
                CI build times will balloon without strict package-level caching. 
                Required change: Add a mandatory pre-requisite milestone for workspace caching.
            }
        }
        @participant(user: "elias", level: 2)
    }

    // Contextual External References
    @references {
        @ref(type: "URL", value: "https://github.com/org/repo/issues/104", description: "Initial performance benchmark issue")
    }

    // Version Lineage Audit Trail
    @history {
        @revision(version: "1.0", event: "submitted", timestamp: 2026-06-06T10:00:00Z)
        @revision(version: "1.1", event: "amendment-adopted", timestamp: 2026-06-06T14:30:00Z) {
            note: "Adopted Sofia's caching prerequisite."
        }
    }
}

```

---

## 7. HTTP API Interface (hica Backend)

The backend accepts HML input over HTTP endpoints to execute state checks and document mutations:

* `GET /health`: Returns JSON service and SQLite readiness for deployment health checks.
* `POST /v1/proposals/submit`: Parses raw HML, validates required tags, initializes state to `submission`, and returns the canonical `v1.0` HML document.
* `POST /v1/proposals/evaluate`: Accepts an updated HML document string containing updated participant states/amendments. Evaluates internal impact logic, executes minor/major version bumps, updates participant status, and returns the transitioned HML document.
* `GET /v1/proposals/{id}`: Returns the current HML document state and complete revision history chain.