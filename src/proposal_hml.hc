import "hml"
import "./domain"

pub type ProposalError {
  ProposalSyntaxError(message: string),
  ProposalValidationError(message: string)
}

pub fun required_attr_str(element: Hml, key: string) : result<string, ProposalError> {
  match hml_attr(element, key) {
    Some(HStr(value)) => Ok(value),
    Some(_) => Err(ProposalValidationError("attribute '" + key + "' must be a string")),
    None => Err(ProposalValidationError("missing attribute '" + key + "'"))
  }
}

pub fun required_attr_int(element: Hml, key: string) : result<int, ProposalError> {
  match hml_attr(element, key) {
    Some(HInt(value)) => Ok(value),
    Some(_) => Err(ProposalValidationError("attribute '" + key + "' must be an integer")),
    None => Err(ProposalValidationError("missing attribute '" + key + "'"))
  }
}

pub fun required_prop_str(nodes: list<HmlNode>, key: string) : result<string, ProposalError> {
  match hml_get(nodes, key) {
    Some(HStr(value)) => Ok(value),
    Some(_) => Err(ProposalValidationError("property '" + key + "' must be a string")),
    None => Err(ProposalValidationError("missing property '" + key + "'"))
  }
}

pub fun optional_prop_str(nodes: list<HmlNode>, key: string) : result<string, ProposalError> {
  match hml_get(nodes, key) {
    Some(HStr(value)) => Ok(value),
    Some(_) => Err(ProposalValidationError("property '" + key + "' must be a string")),
    None => Ok("")
  }
}

pub fun required_body(element: Hml, name: string) : result<list<HmlNode>, ProposalError> {
  match hml_body(element) {
    Some(body) => Ok(body),
    None => Err(ProposalValidationError("element '" + name + "' must have a body"))
  }
}

pub fun required_child(nodes: list<HmlNode>, name: string) : result<Hml, ProposalError> {
  match hml_elem(nodes, name) {
    Some(element) => Ok(element),
    None => Err(ProposalValidationError("missing element '@" + name + "'"))
  }
}

pub fun decode_status(hval: string) : result<ProposalStatus, ProposalError> => match hval {
  "submission" => Ok(Submission),
  "review" => Ok(Review),
  "refinement" => Ok(Refinement),
  "passed" => Ok(Passed),
  _ => Err(ProposalValidationError("unknown proposal status '" + hval + "'"))
}

pub fun decode_datetime_attr(element: Hml, key: string) : result<string, ProposalError> {
  match hml_attr(element, key) {
    Some(HDatetime(value)) => Ok(value),
    Some(_) => Err(ProposalValidationError("attribute '" + key + "' must be a datetime")),
    None => Err(ProposalValidationError("missing attribute '" + key + "'"))
  }
}

pub fun decode_created(nodes: list<HmlNode>) : result<string, ProposalError> {
  match hml_get(nodes, "created") {
    Some(HDatetime(value)) => Ok(value),
    Some(_) => Err(ProposalValidationError("property 'created' must be a datetime")),
    None => Err(ProposalValidationError("missing property 'created'"))
  }
}

pub fun decode_cooling_period(nodes: list<HmlNode>) : result<(int, string), ProposalError> {
  match hml_get(nodes, "cooling-period") {
    Some(HDuration(amount, unit)) => Ok((amount, unit)),
    Some(_) => Err(ProposalValidationError("property 'cooling-period' must be a duration")),
    None => Err(ProposalValidationError("missing property 'cooling-period'"))
  }
}

pub fun decode_amendment(element: Hml) : result<Amendment, ProposalError> {
  let target_version = required_attr_str(element, "target-version")?
  let amendment_status = required_attr_str(element, "status")?
  let body = required_body(element, "amendment")?
  let text = hml_texts(body)
  if length(text) == 0 {
    Err(ProposalValidationError("amendment text must not be empty"))
  } else {
    Ok(Amendment {
      target_version: target_version,
      status: amendment_status,
      text: text
    })
  }
}

pub fun decode_optional_amendment(nodes: list<HmlNode>) : result<maybe<Amendment>, ProposalError> {
  match hml_elem(nodes, "amendment") {
    None => Ok(None),
    Some(element) => {
      let amendment = decode_amendment(element)?
      Ok(Some(amendment))
    }
  }
}

pub fun decode_participant(element: Hml) : result<Participant, ProposalError> {
  let user = required_attr_str(element, "user")?
  let level = required_attr_int(element, "level")?
  if level < 0 || level > 3 {
    Err(ProposalValidationError("participant '" + user + "' has a level outside 0..3"))
  } else {
    let body = required_body(element, "participant")?
    let amendment = decode_optional_amendment(body)?
    if level <= 1 && is_none(amendment) {
      Err(ProposalValidationError("participant '" + user + "' requires an amendment at Level 0 or Level 1"))
    } else {
      Ok(Participant { user: user, level: level, amendment: amendment })
    }
  }
}

pub fun has_participant(users: list<string>, user: string) : bool {
  match users {
    [] => false,
    [first, ..rest] => if first == user { true } else { has_participant(rest, user) }
  }
}

pub fun decode_participants(elements: list<Hml>, users: list<string>) : result<list<Participant>, ProposalError> {
  match elements {
    [] => Ok([]),
    [element, ..rest] => {
      let participant = decode_participant(element)?
      if has_participant(users, participant.user) {
        Err(ProposalValidationError("duplicate participant '" + participant.user + "'"))
      } else {
        let remaining = decode_participants(rest, users + [participant.user])?
        Ok([participant] + remaining)
      }
    }
  }
}

pub fun decode_reference(element: Hml) : result<ProposalReference, ProposalError> {
  let ref_type = required_attr_str(element, "type")?
  let value = required_attr_str(element, "value")?
  let description = required_attr_str(element, "description")?
  Ok(ProposalReference {
    ref_type: ref_type,
    value: value,
    description: description
  })
}

pub fun decode_references(elements: list<Hml>) : result<list<ProposalReference>, ProposalError> {
  match elements {
    [] => Ok([]),
    [element, ..rest] => {
      let reference = decode_reference(element)?
      let remaining = decode_references(rest)?
      Ok([reference] + remaining)
    }
  }
}

pub fun decode_revision(element: Hml) : result<Revision, ProposalError> {
  let version = required_attr_str(element, "version")?
  let event = required_attr_str(element, "event")?
  let timestamp = decode_datetime_attr(element, "timestamp")?
  let body = required_body(element, "revision")?
  let note = optional_prop_str(body, "note")?
  Ok(Revision {
    version: version,
    event: event,
    timestamp: timestamp,
    note: note
  })
}

pub fun decode_revisions(elements: list<Hml>) : result<list<Revision>, ProposalError> {
  match elements {
    [] => Ok([]),
    [element, ..rest] => {
      let revision = decode_revision(element)?
      let remaining = decode_revisions(rest)?
      Ok([revision] + remaining)
    }
  }
}

pub fun required_namespace(nodes: list<HmlNode>) : result<string, ProposalError> {
  match hml_namespace(nodes, "decision") {
    Some(uri) => Ok(uri),
    None => Err(ProposalValidationError("missing decision namespace"))
  }
}

pub fun decode_proposal_nodes(nodes: list<HmlNode>) : result<Proposal, ProposalError> {
  let namespace_uri = required_namespace(nodes)?
  let element = required_child(nodes, "proposal")?
  let proposal_id = required_attr_str(element, "id")?
  let version = required_attr_str(element, "version")?
  let status_value = required_attr_str(element, "status")?
  let status = decode_status(status_value)?
  let body = required_body(element, "proposal")?
  let title = required_prop_str(body, "title")?
  let created = decode_created(body)?
  let cooling_period = decode_cooling_period(body)?

  let body_element = required_child(body, "body")?
  let body_nodes = required_body(body_element, "body")?
  let body_text = hml_texts(body_nodes)
  if length(body_text) == 0 {
    Err(ProposalValidationError("proposal body text must not be empty"))
  } else {
    let participants_element = required_child(body, "participants")?
    let participants_body = required_body(participants_element, "participants")?
    let participants = decode_participants(hml_elems(participants_body, "participant"), [])?
    if length(participants) == 0 {
      Err(ProposalValidationError("proposal must have at least one participant"))
    } else {
      let references = match hml_elem(body, "references") {
        None => [],
        Some(references_element) => {
          let references_body = required_body(references_element, "references")?
          decode_references(hml_elems(references_body, "ref"))?
        }
      }
      let history_element = required_child(body, "history")?
      let history_body = required_body(history_element, "history")?
      let history = decode_revisions(hml_elems(history_body, "revision"))?
      Ok(Proposal {
        proposal_id: proposal_id,
        version: version,
        status: status,
        title: title,
        created: created,
        cooling_period: cooling_period,
        body: body_text,
        participants: participants,
        references: references,
        history: history,
        namespace_uri: namespace_uri
      })
    }
  }
}

pub fun encode_status(proposal_status: ProposalStatus) : string => match proposal_status {
  Submission => "submission",
  Review => "review",
  Refinement => "refinement",
  Passed => "passed"
}

pub fun encode_text_nodes(text: list<string>) : list<HmlNode> =>
  map(text, (line) => NText(line))

pub fun encode_amendment(amendment: Amendment) : Hml =>
  HElement(
    "amendment",
    [
      ("target-version", HStr(amendment.target_version)),
      ("status", HStr(amendment.status))
    ],
    encode_text_nodes(amendment.text)
  )

pub fun encode_participant(participant: Participant) : Hml {
  let body = match participant.amendment {
    None => [],
    Some(amendment) => [NElem(encode_amendment(amendment))]
  }
  HElement(
    "participant",
    [
      ("user", HStr(participant.user)),
      ("level", HInt(participant.level))
    ],
    body
  )
}

pub fun encode_reference(reference: ProposalReference) : Hml =>
  HElement(
    "ref",
    [
      ("type", HStr(reference.ref_type)),
      ("value", HStr(reference.value)),
      ("description", HStr(reference.description))
    ],
    []
  )

pub fun encode_revision(revision: Revision) : Hml {
  let body = if revision.note == "" {
    []
  } else {
    [NProp("note", HStr(revision.note))]
  }
  HElement(
    "revision",
    [
      ("version", HStr(revision.version)),
      ("event", HStr(revision.event)),
      ("timestamp", HDatetime(revision.timestamp))
    ],
    body
  )
}

pub fun encode_proposal_nodes(proposal: Proposal) : list<HmlNode> {
  let proposal_body = [
    NProp("title", HStr(proposal.title)),
    NProp("created", HDatetime(proposal.created)),
    NProp("cooling-period", HDuration(proposal.cooling_period.0, proposal.cooling_period.1)),
    NElem(HElement("body", [], encode_text_nodes(proposal.body))),
    NElem(HElement(
      "participants",
      [],
      map(proposal.participants, (participant) => NElem(encode_participant(participant)))
    )),
    NElem(HElement(
      "references",
      [],
      map(proposal.references, (reference) => NElem(encode_reference(reference)))
    )),
    NElem(HElement(
      "history",
      [],
      map(proposal.history, (revision) => NElem(encode_revision(revision)))
    ))
  ]
  [
    NNamespace("decision", proposal.namespace_uri),
    NElem(HElement(
      "proposal",
      [
        ("id", HStr(proposal.proposal_id)),
        ("version", HStr(proposal.version)),
        ("status", HStr(encode_status(proposal.status)))
      ],
      proposal_body
    ))
  ]
}

pub fun encode_proposal(proposal: Proposal) : string =>
  "#hml 0.3\n#text: amendment\n" + hml_pretty(encode_proposal_nodes(proposal), 0)

pub fun decode_proposal(input: string) : result<Proposal, ProposalError> {
  match hml_parse(input) {
    Err(message) => Err(ProposalSyntaxError(message)),
    Ok(nodes) => decode_proposal_nodes(nodes)
  }
}
