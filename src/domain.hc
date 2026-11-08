pub type ProposalStatus {
  Submission,
  Review,
  Refinement,
  Passed
}

pub type ComfortEvaluationError {
  MissingComfortAmendment(user: string),
  IllegalStatusTransition(from_status: string, to_status: string),
  StaleVersionMismatch(expected: string, actual: string),
  ProposalIdMismatch(expected: string, actual: string),
  WrongVersionAmendment(target_version: string, expected_version: string),
  AlreadyResolvedAmendment(user: string),
  AmbiguousAmendment(message: string)
}

pub struct Amendment {
  target_version: string,
  status: string,
  text: list<string>
}

pub struct Participant {
  user: string,
  level: int,
  amendment: maybe<Amendment>
}

pub struct ProposalReference {
  ref_type: string,
  value: string,
  description: string
}

pub struct Revision {
  version: string,
  event: string,
  timestamp: string,
  note: string
}

pub struct Proposal {
  proposal_id: string,
  version: string,
  status: ProposalStatus,
  title: string,
  created: string,
  cooling_period: (int, string),
  body: list<string>,
  participants: list<Participant>,
  references: list<ProposalReference>,
  history: list<Revision>,
  namespace_uri: string
}

pub fun parse_semver(v: string) : maybe<(int, int)> {
  match split(v, ".") {
    [maj_s, min_s] => match (parse_int(maj_s), parse_int(min_s)) {
      (Some(maj), Some(min)) => if maj >= 0 && min >= 0 {
        Some((maj, min))
      } else {
        None
      },
      _ => None
    },
    _ => None
  }
}

pub fun bump_minor_version(v: string) : maybe<string> {
  match parse_semver(v) {
    Some((maj, min)) => Some(show(maj) + "." + show(min + 1)),
    None => None
  }
}

pub fun bump_major_version(v: string) : maybe<string> {
  match parse_semver(v) {
    Some((maj, _)) => Some(show(maj + 1) + ".0"),
    None => None
  }
}

pub fun initialize_submission(proposal: Proposal) : Proposal {
  let version = "1.0"
  Proposal {
    ...proposal,
    version: version,
    status: Submission,
    history: [Revision {
      version: version,
      event: "submitted",
      timestamp: proposal.created,
      note: ""
    }]
  }
}

pub fun evaluate_comfort(participants: list<Participant>) : result<ProposalStatus, ComfortEvaluationError> {
  let missing = find(participants, (participant) =>
    if participant.level == 0 || participant.level == 1 {
      match participant.amendment {
        None => true,
        Some(amendment) => length(amendment.text) == 0
      }
    } else {
      false
    }
  )
  match missing {
    Some(participant) => Err(MissingComfortAmendment(participant.user)),
    None => if any(participants, (participant) => participant.level == 0 || participant.level == 1) {
      Ok(Refinement)
    } else {
      Ok(Passed)
    }
  }
}

pub fun status_to_string(status: ProposalStatus) : string => match status {
  Submission => "submission",
  Review => "review",
  Refinement => "refinement",
  Passed => "passed"
}

pub fun is_transition_legal(from_status: ProposalStatus, to_status: ProposalStatus) : bool => match (from_status, to_status) {
  (Submission, Review) => true,
  (Submission, Refinement) => true,
  (Submission, Passed) => true,
  (Review, Review) => true,
  (Review, Refinement) => true,
  (Review, Passed) => true,
  (Refinement, Refinement) => true,
  (Refinement, Passed) => true,
  (Refinement, Review) => true,
  _ => false
}

fun is_already_adopted_in_active(target_user: string, active_participants: list<Participant>) : bool =>
  any(active_participants, (ap) => ap.user == target_user && match ap.amendment {
    Some(aa) => aa.status == "adopted",
    None => false
  })

fun is_new_adoption(p: Participant, active_participants: list<Participant>) : bool =>
  match p.amendment {
    Some(a) => a.status == "adopted" && !is_already_adopted_in_active(p.user, active_participants),
    None => false
  }

fun find_adopted_pair(
  participants: list<Participant>,
  active_participants: list<Participant>
) : maybe<(Participant, Amendment)> {
  match participants {
    [] => None,
    [p, ..rest] => if is_new_adoption(p, active_participants) {
      match p.amendment {
        Some(a) => Some((p, a)),
        None => find_adopted_pair(rest, active_participants)
      }
    } else {
      find_adopted_pair(rest, active_participants)
    }
  }
}

fun find_rejected_target_version(participants: list<Participant>) : maybe<string> {
  match participants {
    [] => None,
    [p, ..rest] => match p.amendment {
      Some(a) => if a.status == "rejected" {
        Some(a.target_version)
      } else {
        find_rejected_target_version(rest)
      },
      None => find_rejected_target_version(rest)
    }
  }
}

fun count_adopted_amendments(
  participants: list<Participant>,
  active_participants: list<Participant>
) : int {
  let adopted_list = filter(participants, (p) => is_new_adoption(p, active_participants))
  length(adopted_list)
}

fun find_already_resolved_participant(
  incoming_participants: list<Participant>,
  active_participants: list<Participant>
) : maybe<string> {
  match incoming_participants {
    [] => None,
    [p, ..rest] => match p.amendment {
      Some(a) => if a.status == "adopted" && p.level <= 1 && is_already_adopted_in_active(p.user, active_participants) {
        Some(p.user)
      } else {
        find_already_resolved_participant(rest, active_participants)
      },
      None => find_already_resolved_participant(rest, active_participants)
    }
  }
}

fun update_participant_adoption(
  participants: list<Participant>,
  adopted_user: string,
  new_version: string
) : list<Participant> {
  map(participants, (p) =>
    if p.user == adopted_user {
      let updated_amendment = match p.amendment {
        Some(a) => Some(Amendment {
          target_version: new_version,
          status: "adopted",
          text: a.text
        }),
        None => None
      }
      Participant {
        user: p.user,
        level: 2,
        amendment: updated_amendment
      }
    } else {
      p
    }
  )
}

fun reset_participants_for_review(
  active_participants: list<Participant>,
  incoming_participants: list<Participant>
) : list<Participant> {
  let source = if length(incoming_participants) > 0 {
    incoming_participants
  } else {
    active_participants
  }
  match source {
    [] => [],
    [author, .._] => [Participant {
      user: author.user,
      level: 3,
      amendment: None
    }]
  }
}

fun handle_amendment_adoption(
  active: Proposal,
  incoming: Proposal,
  timestamp: string
) : result<Proposal, ComfortEvaluationError> {
  match find_adopted_pair(incoming.participants, active.participants) {
    None => Err(AmbiguousAmendment("no adopted amendment found")),
    Some((adopted_p, adopted_amendment)) => {
      let next_minor = unwrap_maybe_or(bump_minor_version(active.version), "")
      if next_minor == "" {
        Err(IllegalStatusTransition(status_to_string(active.status), "invalid_version"))
      } else if adopted_amendment.target_version != active.version && adopted_amendment.target_version != next_minor {
        Err(WrongVersionAmendment(adopted_amendment.target_version, active.version))
      } else if incoming.version != active.version && incoming.version != next_minor {
        Err(StaleVersionMismatch(active.version, incoming.version))
      } else if is_already_adopted_in_active(adopted_p.user, active.participants) {
        Err(AlreadyResolvedAmendment(adopted_p.user))
      } else {
        let note = match last(incoming.history) {
          Some(rev) => if rev.event == "amendment-adopted" && rev.note != "" {
            rev.note
          } else {
            "Adopted " + adopted_p.user + "'s amendment."
          },
          None => "Adopted " + adopted_p.user + "'s amendment."
        }
        let new_revision = Revision {
          version: next_minor,
          event: "amendment-adopted",
          timestamp: timestamp,
          note: note
        }
        let updated_participants = update_participant_adoption(
          incoming.participants,
          adopted_p.user,
          next_minor
        )
        Ok(Proposal {
          ...active,
          version: next_minor,
          status: Refinement,
          body: incoming.body,
          participants: updated_participants,
          history: active.history + [new_revision]
        })
      }
    }
  }
}

fun handle_directional_shift(
  active: Proposal,
  incoming: Proposal,
  rejected_target_maybe: maybe<string>,
  timestamp: string
) : result<Proposal, ComfortEvaluationError> {
  let next_major = unwrap_maybe_or(bump_major_version(active.version), "")
  if next_major == "" {
    Err(IllegalStatusTransition(status_to_string(active.status), "invalid_version"))
  } else if incoming.version != active.version && incoming.version != next_major {
    Err(StaleVersionMismatch(active.version, incoming.version))
  } else {
    let wrong_version = match rejected_target_maybe {
      Some(target_v) => if target_v != active.version && target_v != next_major {
        Some(target_v)
      } else {
        None
      },
      None => None
    }
    match wrong_version {
      Some(target_v) => Err(WrongVersionAmendment(target_v, active.version)),
      None => {
        let note = match last(incoming.history) {
          Some(rev) => if rev.event == "directional-shift" && rev.note != "" {
            rev.note
          } else {
            "Directional shift addressing reservations."
          },
          None => "Directional shift addressing reservations."
        }
        let new_revision = Revision {
          version: next_major,
          event: "directional-shift",
          timestamp: timestamp,
          note: note
        }
        let reset_participants = reset_participants_for_review(
          active.participants,
          incoming.participants
        )
        Ok(Proposal {
          ...active,
          version: next_major,
          status: Review,
          body: incoming.body,
          participants: reset_participants,
          history: active.history + [new_revision]
        })
      }
    }
  }
}

fun evaluate_default_transition(
  active: Proposal,
  incoming: Proposal,
  timestamp: string
) : result<Proposal, ComfortEvaluationError> {
  let is_incoming_review = match incoming.status {
    Review => true,
    _ => false
  }
  let can_enter_review = match active.status {
    Submission => true,
    Review => true,
    _ => false
  }
  let target_result = if is_incoming_review && can_enter_review {
    Ok(Review)
  } else {
    evaluate_comfort(incoming.participants)
  }
  match target_result {
    Err(error) => Err(error),
    Ok(target_status) => if !is_transition_legal(active.status, target_status) {
      Err(IllegalStatusTransition(status_to_string(active.status), status_to_string(target_status)))
    } else {
      let event = match target_status {
        Passed => "passed",
        Refinement => "refinement",
        Review => "review-started",
        Submission => "submitted"
      }
      let note = match target_status {
        Passed => "All participants consented.",
        Refinement => "Reservations require refinement.",
        Review => "Cooling review period started.",
        Submission => ""
      }
      let new_revision = Revision {
        version: active.version,
        event: event,
        timestamp: timestamp,
        note: note
      }
      Ok(Proposal {
        ...active,
        status: target_status,
        participants: incoming.participants,
        history: active.history + [new_revision]
      })
    }
  }
}

pub fun evaluate_proposal_transition(
  active: Proposal,
  incoming: Proposal,
  timestamp: string
) : result<Proposal, ComfortEvaluationError> {
  if incoming.proposal_id != active.proposal_id {
    Err(ProposalIdMismatch(active.proposal_id, incoming.proposal_id))
  } else {
    match active.status {
      Refinement => {
        match find_already_resolved_participant(incoming.participants, active.participants) {
          Some(user) => Err(AlreadyResolvedAmendment(user)),
          None => {
            let adopted_count = count_adopted_amendments(incoming.participants, active.participants)
            let rejected_target_maybe = find_rejected_target_version(incoming.participants)
            let is_review = match incoming.status {
              Review => true,
              _ => false
            }
            let has_shift = is_some(rejected_target_maybe) ||
              is_review ||
              any(incoming.history, (r) => r.event == "directional-shift")
            if adopted_count > 1 {
              Err(AmbiguousAmendment("multiple amendments adopted simultaneously"))
            } else if adopted_count == 1 {
              handle_amendment_adoption(active, incoming, timestamp)
            } else if has_shift {
              handle_directional_shift(active, incoming, rejected_target_maybe, timestamp)
            } else if incoming.version != active.version {
              Err(StaleVersionMismatch(active.version, incoming.version))
            } else {
              evaluate_default_transition(active, incoming, timestamp)
            }
          }
        }
      },
      _ => if incoming.version != active.version {
        Err(StaleVersionMismatch(active.version, incoming.version))
      } else {
        evaluate_default_transition(active, incoming, timestamp)
      }
    }
  }
}
