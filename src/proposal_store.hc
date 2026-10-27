import "sqlite"
import "./db"
import "./domain"
import "./proposal_hml"

pub fun create_proposal(db: Db, proposal: Proposal) {
  create_stored_proposal(
    db,
    proposal.proposal_id,
    proposal.version,
    encode_status(proposal.status),
    encode_proposal(proposal)
  )
}

pub fun append_revision(db: Db, proposal: Proposal) {
  append_stored_revision(
    db,
    proposal.proposal_id,
    proposal.version,
    encode_status(proposal.status),
    encode_proposal(proposal)
  )
}
