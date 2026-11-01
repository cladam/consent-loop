pub type ProposalStatus {
  Submission,
  Review,
  Refinement,
  Passed
}

pub type ComfortEvaluationError {
  MissingComfortAmendment(user: string)
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
