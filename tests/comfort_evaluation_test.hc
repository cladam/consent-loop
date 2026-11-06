import "../src/domain"

fun concrete_amendment() : Amendment => Amendment {
  target_version: "1.0",
  status: "proposed",
  text: ["Clarify the operational boundary."]
}

fun comfort_participant(user: string, level: int, amendment: maybe<Amendment>) : Participant =>
  Participant { user: user, level: level, amendment: amendment }

test "all comfortable participants pass" {
  let result = evaluate_comfort([
    comfort_participant("alex", 3, None),
    comfort_participant("elias", 2, None)
  ])

  assert(result == Ok(Passed))
}

test "hesitant participant enters refinement" {
  let result = evaluate_comfort([
    comfort_participant("alex", 3, None),
    comfort_participant("sofia", 1, Some(concrete_amendment()))
  ])

  assert(result == Ok(Refinement))
}

test "blocked participant enters refinement" {
  let result = evaluate_comfort([
    comfort_participant("alex", 0, Some(concrete_amendment())),
    comfort_participant("sofia", 2, None)
  ])

  assert(result == Ok(Refinement))
}

test "mixed comfort levels enter refinement" {
  let result = evaluate_comfort([
    comfort_participant("alex", 3, None),
    comfort_participant("sofia", 1, Some(concrete_amendment())),
    comfort_participant("elias", 2, None)
  ])

  assert(result == Ok(Refinement))
}

test "low comfort requires a concrete amendment" {
  match evaluate_comfort([comfort_participant("sofia", 1, None)]) {
    Err(MissingComfortAmendment(user)) => assert(user == "sofia"),
    _ => assert(false)
  }
}

test "empty amendment text is not concrete" {
  let empty = Amendment { target_version: "1.0", status: "proposed", text: [] }
  match evaluate_comfort([comfort_participant("sofia", 0, Some(empty))]) {
    Err(MissingComfortAmendment(user)) => assert(user == "sofia"),
    _ => assert(false)
  }
}

test "equivalent participant order is deterministic" {
  let alex = comfort_participant("alex", 3, None)
  let sofia = comfort_participant("sofia", 1, Some(concrete_amendment()))

  assert(evaluate_comfort([alex, sofia]) == evaluate_comfort([sofia, alex]))
}

fun sample_proposal(proposal_id: string, status: ProposalStatus, participants: list<Participant>) : Proposal {
  Proposal {
    proposal_id: proposal_id,
    version: "1.0",
    status: status,
    title: "Sample Proposal",
    created: "2026-06-06T10:00:00Z",
    cooling_period: (24, "h"),
    body: ["Sample body text."],
    participants: participants,
    references: [],
    history: [Revision {
      version: "1.0",
      event: "submitted",
      timestamp: "2026-06-06T10:00:00Z",
      note: ""
    }],
    namespace_uri: "https://hica.dev/schemas/decision/v1"
  }
}

test "all participants at level 2 or 3 transitions to passed" {
  let active = sample_proposal("PROP-1", Submission, [
    comfort_participant("alex", 3, None),
    comfort_participant("elias", 2, None)
  ])
  let incoming = sample_proposal("PROP-1", Submission, [
    comfort_participant("alex", 3, None),
    comfort_participant("elias", 2, None)
  ])
  match evaluate_proposal_transition(active, incoming, "2026-06-06T12:00:00Z") {
    Err(_) => assert(false),
    Ok(result) => {
      assert(result.status == Passed)
      assert(result.version == "1.0")
      assert(length(result.history) == 2)
      match last(result.history) {
        None => assert(false),
        Some(rev) => {
          assert(rev.version == "1.0")
          assert(rev.event == "passed")
          assert(rev.timestamp == "2026-06-06T12:00:00Z")
        }
      }
    }
  }
}

test "dissenting participant at level 1 with amendment transitions to refinement" {
  let active = sample_proposal("PROP-2", Submission, [
    comfort_participant("alex", 3, None)
  ])
  let incoming = sample_proposal("PROP-2", Submission, [
    comfort_participant("alex", 3, None),
    comfort_participant("sofia", 1, Some(concrete_amendment()))
  ])
  match evaluate_proposal_transition(active, incoming, "2026-06-06T12:00:00Z") {
    Err(_) => assert(false),
    Ok(result) => {
      assert(result.status == Refinement)
      assert(length(result.history) == 2)
      match last(result.history) {
        None => assert(false),
        Some(rev) => {
          assert(rev.version == "1.0")
          assert(rev.event == "refinement")
        }
      }
    }
  }
}

test "submission can enter review explicitly" {
  let active = sample_proposal("PROP-3", Submission, [
    comfort_participant("alex", 3, None)
  ])
  let incoming = sample_proposal("PROP-3", Review, [
    comfort_participant("alex", 3, None)
  ])
  match evaluate_proposal_transition(active, incoming, "2026-06-06T11:00:00Z") {
    Err(_) => assert(false),
    Ok(result) => {
      assert(result.status == Review)
      assert(length(result.history) == 2)
      match last(result.history) {
        None => assert(false),
        Some(rev) => {
          assert(rev.event == "review-started")
          assert(rev.timestamp == "2026-06-06T11:00:00Z")
        }
      }
    }
  }
}

test "transition from passed state is rejected as illegal" {
  let active = sample_proposal("PROP-4", Passed, [
    comfort_participant("alex", 3, None)
  ])
  let incoming = sample_proposal("PROP-4", Submission, [
    comfort_participant("alex", 3, None)
  ])
  match evaluate_proposal_transition(active, incoming, "2026-06-06T12:00:00Z") {
    Err(IllegalStatusTransition(from_s, to_s)) => {
      assert(from_s == "passed")
      assert(to_s == "passed")
    },
    _ => assert(false)
  }
}

test "transition with stale version mismatch is rejected" {
  let active = sample_proposal("PROP-5", Submission, [
    comfort_participant("alex", 3, None)
  ])
  let incoming = Proposal {
    ...active,
    version: "0.9"
  }
  match evaluate_proposal_transition(active, incoming, "2026-06-06T12:00:00Z") {
    Err(StaleVersionMismatch(expected, actual)) => {
      assert(expected == "1.0")
      assert(actual == "0.9")
    },
    _ => assert(false)
  }
}
