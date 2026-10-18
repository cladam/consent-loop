pub type ProposalStatus {
  Submission,
  Review,
  Refinement,
  Passed
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
