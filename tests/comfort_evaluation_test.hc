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

test "semver minor and major increments handle 1.9 to 1.10 and 1.10 to 2.0" {
  assert(bump_minor_version("1.0") == Some("1.1"))
  assert(bump_minor_version("1.9") == Some("1.10"))
  assert(bump_minor_version("1.10") == Some("1.11"))
  assert(bump_major_version("1.0") == Some("2.0"))
  assert(bump_major_version("1.9") == Some("2.0"))
  assert(bump_major_version("1.10") == Some("2.0"))
  assert(bump_minor_version("invalid") == None)
  assert(bump_major_version("invalid") == None)
}

test "amendment adoption increments minor version and moves objector to consent" {
  let active = sample_proposal("PROP-ADOPT", Refinement, [
    comfort_participant("alex", 3, None),
    comfort_participant("sofia", 1, Some(Amendment {
      target_version: "1.0",
      status: "proposed",
      text: ["Require package-level caching."]
    }))
  ])
  let incoming = Proposal {
    ...active,
    body: ["Sample body text with caching prerequisite."],
    participants: [
      comfort_participant("alex", 3, None),
      comfort_participant("sofia", 1, Some(Amendment {
        target_version: "1.0",
        status: "adopted",
        text: ["Require package-level caching."]
      }))
    ]
  }
  match evaluate_proposal_transition(active, incoming, "2026-06-06T14:00:00Z") {
    Err(_) => assert(false),
    Ok(result) => {
      assert(result.version == "1.1")
      assert(result.status == Refinement)
      assert(length(result.history) == 2)
      match last(result.history) {
        None => assert(false),
        Some(rev) => {
          assert(rev.version == "1.1")
          assert(rev.event == "amendment-adopted")
          assert(rev.timestamp == "2026-06-06T14:00:00Z")
        }
      }
      let sofia = find(result.participants, (p) => p.user == "sofia")
      match sofia {
        None => assert(false),
        Some(p) => {
          assert(p.level == 2)
          match p.amendment {
            None => assert(false),
            Some(a) => {
              assert(a.target_version == "1.1")
              assert(a.status == "adopted")
            }
          }
        }
      }
    }
  }
}

test "adopted proposal in refinement transitions to passed when evaluated" {
  let active = Proposal {
    ...sample_proposal("PROP-ADOPT-PASS", Refinement, [
      comfort_participant("alex", 3, None),
      comfort_participant("sofia", 2, Some(Amendment {
        target_version: "1.1",
        status: "adopted",
        text: ["Require package-level caching."]
      }))
    ]),
    version: "1.1"
  }
  let incoming = Proposal {
    ...active,
    participants: [
      comfort_participant("alex", 3, None),
      comfort_participant("sofia", 2, None)
    ]
  }
  match evaluate_proposal_transition(active, incoming, "2026-06-06T15:00:00Z") {
    Err(_) => assert(false),
    Ok(result) => {
      assert(result.version == "1.1")
      assert(result.status == Passed)
      match last(result.history) {
        None => assert(false),
        Some(rev) => {
          assert(rev.version == "1.1")
          assert(rev.event == "passed")
        }
      }
    }
  }
}

test "directional shift increments major version and resets review" {
  let active = sample_proposal("PROP-SHIFT", Refinement, [
    comfort_participant("alex", 3, None),
    comfort_participant("sofia", 0, Some(Amendment {
      target_version: "1.0",
      status: "proposed",
      text: ["Fundamental security objection."]
    }))
  ])
  let incoming = Proposal {
    ...active,
    body: ["Rewritten core architecture to eliminate security risk."],
    participants: [
      comfort_participant("alex", 3, None),
      comfort_participant("sofia", 0, Some(Amendment {
        target_version: "1.0",
        status: "rejected",
        text: ["Fundamental security objection."]
      }))
    ]
  }
  match evaluate_proposal_transition(active, incoming, "2026-06-06T16:00:00Z") {
    Err(_) => assert(false),
    Ok(result) => {
      assert(result.version == "2.0")
      assert(result.status == Review)
      assert(length(result.history) == 2)
      match last(result.history) {
        None => assert(false),
        Some(rev) => {
          assert(rev.version == "2.0")
          assert(rev.event == "directional-shift")
          assert(rev.timestamp == "2026-06-06T16:00:00Z")
        }
      }
      assert(length(result.participants) == 1)
      match head(result.participants) {
        None => assert(false),
        Some(p) => {
          assert(p.user == "alex")
          assert(p.level == 3)
          assert(is_none(p.amendment))
        }
      }
    }
  }
}

test "directionally shifted proposal transitions to passed upon new consensus" {
  let active = Proposal {
    ...sample_proposal("PROP-SHIFT-PASS", Review, [
      comfort_participant("alex", 3, None)
    ]),
    version: "2.0"
  }
  let incoming = Proposal {
    ...active,
    status: Submission,
    participants: [
      comfort_participant("alex", 3, None),
      comfort_participant("sofia", 3, None)
    ]
  }
  match evaluate_proposal_transition(active, incoming, "2026-06-06T17:00:00Z") {
    Err(_) => assert(false),
    Ok(result) => {
      assert(result.version == "2.0")
      assert(result.status == Passed)
      match last(result.history) {
        None => assert(false),
        Some(rev) => {
          assert(rev.version == "2.0")
          assert(rev.event == "passed")
        }
      }
    }
  }
}

test "amendment with wrong target version is rejected" {
  let active = sample_proposal("PROP-WRONG", Refinement, [
    comfort_participant("alex", 3, None),
    comfort_participant("sofia", 1, Some(Amendment {
      target_version: "1.0",
      status: "proposed",
      text: ["Prerequisite."]
    }))
  ])
  let incoming = Proposal {
    ...active,
    participants: [
      comfort_participant("alex", 3, None),
      comfort_participant("sofia", 1, Some(Amendment {
        target_version: "3.5",
        status: "adopted",
        text: ["Prerequisite."]
      }))
    ]
  }
  match evaluate_proposal_transition(active, incoming, "2026-06-06T14:00:00Z") {
    Err(WrongVersionAmendment(target_v, expected_v)) => {
      assert(target_v == "3.5")
      assert(expected_v == "1.0")
    },
    _ => assert(false)
  }
}

test "already resolved amendment adoption is rejected" {
  let active = Proposal {
    ...sample_proposal("PROP-ALREADY", Refinement, [
      comfort_participant("alex", 3, None),
      comfort_participant("sofia", 2, Some(Amendment {
        target_version: "1.1",
        status: "adopted",
        text: ["Already adopted."]
      }))
    ]),
    version: "1.1"
  }
  let incoming = Proposal {
    ...active,
    participants: [
      comfort_participant("alex", 3, None),
      comfort_participant("sofia", 1, Some(Amendment {
        target_version: "1.1",
        status: "adopted",
        text: ["Already adopted."]
      }))
    ]
  }
  match evaluate_proposal_transition(active, incoming, "2026-06-06T14:00:00Z") {
    Err(AlreadyResolvedAmendment(user)) => assert(user == "sofia"),
    _ => assert(false)
  }
}

test "ambiguous multiple amendment adoptions are rejected" {
  let active = sample_proposal("PROP-AMBIG", Refinement, [
    comfort_participant("alex", 3, None),
    comfort_participant("sofia", 1, Some(Amendment {
      target_version: "1.0",
      status: "proposed",
      text: ["One."]
    })),
    comfort_participant("elias", 1, Some(Amendment {
      target_version: "1.0",
      status: "proposed",
      text: ["Two."]
    }))
  ])
  let incoming = Proposal {
    ...active,
    participants: [
      comfort_participant("alex", 3, None),
      comfort_participant("sofia", 1, Some(Amendment {
        target_version: "1.0",
        status: "adopted",
        text: ["One."]
      })),
      comfort_participant("elias", 1, Some(Amendment {
        target_version: "1.0",
        status: "adopted",
        text: ["Two."]
      }))
    ]
  }
  match evaluate_proposal_transition(active, incoming, "2026-06-06T14:00:00Z") {
    Err(AmbiguousAmendment(message)) => assert(message == "multiple amendments adopted simultaneously"),
    _ => assert(false)
  }
}
