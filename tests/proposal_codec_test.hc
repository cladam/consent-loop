import "../src/proposal_hml"
import "../src/domain"
import "./fixtures"

test "decode canonical proposal" {
  match decode_proposal(valid_proposal_hml()) {
    Err(ProposalSyntaxError(message)) => {
      println("syntax error: " + message)
      assert(false)
    },
    Err(ProposalValidationError(message)) => {
      println("validation error: " + message)
      assert(false)
    },
    Ok(proposal) => {
      assert(proposal.proposal_id == "PROP-042")
      assert(proposal.version == "1.1")
      assert(length(proposal.participants) == 3)
      assert(length(proposal.references) == 1)
      assert(length(proposal.history) == 2)
    }
  }
}

test "distinguish HML syntax errors" {
  match decode_proposal("@proposal(id: \"PROP-042\"") {
    Err(ProposalSyntaxError(_)) => assert(true),
    _ => assert(false)
  }
}

test "reject missing required title" {
  let input = replace(
    valid_proposal_hml(),
    "  title: \"Migrate services to a trunk-based monorepo\"\n",
    ""
  )
  match decode_proposal(input) {
    Err(ProposalValidationError(message)) => assert(contains(message, "title")),
    _ => assert(false)
  }
}

test "reject duplicate participants" {
  let input = replace(
    valid_proposal_hml(),
    "@participant(user: \"elias\", level: 2)",
    "@participant(user: \"alex\", level: 2)"
  )
  match decode_proposal(input) {
    Err(ProposalValidationError(message)) => assert(contains(message, "duplicate participant")),
    _ => assert(false)
  }
}

test "reject comfort levels outside zero through three" {
  let input = replace(
    valid_proposal_hml(),
    "@participant(user: \"alex\", level: 3)",
    "@participant(user: \"alex\", level: 4)"
  )
  match decode_proposal(input) {
    Err(ProposalValidationError(message)) => assert(contains(message, "outside 0..3")),
    _ => assert(false)
  }
}

test "require amendment for hesitant participant" {
  let input = replace(
    valid_proposal_hml(),
    "@participant(user: \"alex\", level: 3)",
    "@participant(user: \"alex\", level: 1)"
  )
  match decode_proposal(input) {
    Err(ProposalValidationError(message)) => assert(contains(message, "amendment")),
    _ => assert(false)
  }
}

test "canonical HML is stable across a round trip" {
  match decode_proposal(valid_proposal_hml()) {
    Err(_) => assert(false),
    Ok(proposal) => {
      let canonical = encode_proposal(proposal)
      assert(starts_with(canonical, "#hml 0.3\n#text: amendment\n"))
      match decode_proposal(canonical) {
        Err(_) => assert(false),
        Ok(roundtripped) => {
          assert(roundtripped == proposal)
          assert(encode_proposal(roundtripped) == canonical)
        }
      }
    }
  }
}
