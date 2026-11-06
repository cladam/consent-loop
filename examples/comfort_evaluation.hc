import "../src/db"
import "../src/domain"
import "../src/proposal_hml"
import "../src/proposal_store"
import "sqlite"

fun print_history(revisions: list<StoredRevision>) {
  match revisions {
    [] => {},
    [revision, ..rest] => {
      println(revision.version + " " + revision.status)
      print_history(rest)
    }
  }
}

fun sample_proposal(id_str: string, participants: list<Participant>) : Proposal {
  Proposal {
    proposal_id: id_str,
    version: "1.0",
    status: Submission,
    title: "Cache Layer Architecture",
    created: "2026-06-06T10:00:00Z",
    cooling_period: (24, "h"),
    body: ["Implement distributed caching."],
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

fun main() {
  let db = unwrap(sqlite_open(":memory:"))
  let _ = init_db(db)
  let pid = "PROP-EVAL-001"

  let initial = sample_proposal(pid, [
    Participant { user: "alex", level: 3, amendment: None }
  ])
  let _ = create_proposal(db, initial)

  let dissenting = Proposal {
    ...initial,
    participants: [
      Participant { user: "alex", level: 3, amendment: None },
      Participant {
        user: "sofia",
        level: 1,
        amendment: Some(Amendment {
          target_version: "1.0",
          status: "proposed",
          text: ["Add eviction policy before rollout."]
        })
      }
    ]
  }

  match evaluate_proposal_transition(initial, dissenting, "2026-06-06T12:00:00Z") {
    Err(_) => eprintln("evaluation failed"),
    Ok(refined) => {
      let _ = append_revision(db, refined)
      match fetch_active_revision(db, pid) {
        Ok(Some(active)) => println("active after dissent: " + active.version + " " + active.status),
        _ => eprintln("active revision not found")
      }
    }
  }

  match fetch_revision_history(db, pid) {
    Ok(revisions) => print_history(revisions),
    Err(error) => eprintln("history error: " + error.message)
  }
}
