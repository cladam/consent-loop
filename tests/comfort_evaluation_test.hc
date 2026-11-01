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
