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
  ProposalIdMismatch(expected: string, actual: string)
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
  _ => false
}

pub fun evaluate_proposal_transition(
  active: Proposal,
  incoming: Proposal,
  timestamp: string
) : result<Proposal, ComfortEvaluationError> {
  if incoming.proposal_id != active.proposal_id {
    Err(ProposalIdMismatch(active.proposal_id, incoming.proposal_id))
  } else if incoming.version != active.version {
    Err(StaleVersionMismatch(active.version, incoming.version))
  } else {
    let target_result = if incoming.status == Review && (active.status == Submission || active.status == Review) {
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
}
