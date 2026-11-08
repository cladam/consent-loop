import "../src/db"
import "../src/domain"
import "../src/proposal_hml"
import "../src/proposal_store"
import "sqlite"

fun print_history(revisions: list<StoredRevision>) {
  match revisions {
    [] => {},
    [revision, ..rest] => {
      println("  " + revision.version + " [" + revision.status + "]")
      print_history(rest)
    }
  }
}

fun sample_proposal(id_str: string, title_str: string) : Proposal {
  Proposal {
    proposal_id: id_str,
    version: "1.0",
    status: Submission,
    title: title_str,
    created: "2026-06-06T10:00:00Z",
    cooling_period: (24, "h"),
    body: ["Initial proposal text."],
    participants: [
      Participant { user: "alex", level: 3, amendment: None }
    ],
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

  println("=== ConsentLoop M5: Amendment Resolution & Semantic Versioning ===")

  // Path 1: Amendment Adoption (Minor Bump 1.0 -> 1.1 -> Passed)
  let pid1 = "PROP-ADOPT-001"
  let initial1 = sample_proposal(pid1, "Monorepo Migration")
  let _ = create_proposal(db, initial1)

  let dissenting1 = Proposal {
    ...initial1,
    participants: [
      Participant { user: "alex", level: 3, amendment: None },
      Participant {
        user: "sofia",
        level: 1,
        amendment: Some(Amendment {
          target_version: "1.0",
          status: "proposed",
          text: ["Add mandatory workspace caching."]
        })
      }
    ]
  }

  match evaluate_proposal_transition(initial1, dissenting1, "2026-06-06T11:00:00Z") {
    Err(_) => eprintln("dissent failed"),
    Ok(refined1) => {
      let _ = append_revision(db, refined1)

      // Author adopts Sofia's amendment
      let adopting1 = Proposal {
        ...refined1,
        body: ["Monorepo migration with mandatory workspace caching."],
        participants: [
          Participant { user: "alex", level: 3, amendment: None },
          Participant {
            user: "sofia",
            level: 1,
            amendment: Some(Amendment {
              target_version: "1.0",
              status: "adopted",
              text: ["Add mandatory workspace caching."]
            })
          }
        ]
      }

      match evaluate_proposal_transition(refined1, adopting1, "2026-06-06T14:00:00Z") {
        Err(_) => eprintln("adoption failed"),
        Ok(adopted1) => {
          let _ = append_revision(db, adopted1)

          // Comfort evaluation with consensual participants
          let passing1 = Proposal {
            ...adopted1,
            status: Submission,
            participants: [
              Participant { user: "alex", level: 3, amendment: None },
              Participant {
                user: "sofia",
                level: 2,
                amendment: Some(Amendment {
                  target_version: "1.1",
                  status: "adopted",
                  text: ["Add mandatory workspace caching."]
                })
              }
            ]
          }

          match evaluate_proposal_transition(adopted1, passing1, "2026-06-06T16:00:00Z") {
            Err(_) => eprintln("passing failed"),
            Ok(passed1) => {
              let _ = append_revision(db, passed1)
              println("\nPath 1 (Adoption): " + pid1 + " reached " + passed1.version + " " + status_to_string(passed1.status))
            }
          }
        }
      }
    }
  }

  match fetch_revision_history(db, pid1) {
    Ok(history) => {
      println("Audit trail for " + pid1 + ":")
      print_history(history)
    },
    Err(e) => eprintln("history error: " + e.message)
  }

  // Path 2: Directional Shift (Major Bump 1.0 -> 2.0 -> Passed)
  let pid2 = "PROP-SHIFT-002"
  let initial2 = sample_proposal(pid2, "Centralized Event Bus")
  let _ = create_proposal(db, initial2)

  let dissenting2 = Proposal {
    ...initial2,
    participants: [
      Participant { user: "alex", level: 3, amendment: None },
      Participant {
        user: "sofia",
        level: 0,
        amendment: Some(Amendment {
          target_version: "1.0",
          status: "proposed",
          text: ["Central broker creates single point of failure."]
        })
      }
    ]
  }

  match evaluate_proposal_transition(initial2, dissenting2, "2026-06-06T12:00:00Z") {
    Err(_) => eprintln("dissent failed"),
    Ok(refined2) => {
      let _ = append_revision(db, refined2)

      // Author rejects amendment and rewrites core architecture
      let shifting2 = Proposal {
        ...refined2,
        body: ["Peer-to-peer event mesh eliminating single point of failure."],
        participants: [
          Participant { user: "alex", level: 3, amendment: None },
          Participant {
            user: "sofia",
            level: 0,
            amendment: Some(Amendment {
              target_version: "1.0",
              status: "rejected",
              text: ["Central broker creates single point of failure."]
            })
          }
        ]
      }

      match evaluate_proposal_transition(refined2, shifting2, "2026-06-06T15:00:00Z") {
        Err(_) => eprintln("shift failed"),
        Ok(shifted2) => {
          let _ = append_revision(db, shifted2)

          // Participants register comfort on the 2.0 draft
          let passing2 = Proposal {
            ...shifted2,
            status: Submission,
            participants: [
              Participant { user: "alex", level: 3, amendment: None },
              Participant { user: "sofia", level: 3, amendment: None }
            ]
          }

          match evaluate_proposal_transition(shifted2, passing2, "2026-06-06T18:00:00Z") {
            Err(_) => eprintln("passing 2.0 failed"),
            Ok(passed2) => {
              let _ = append_revision(db, passed2)
              println("\nPath 2 (Directional Shift): " + pid2 + " reached " + passed2.version + " " + status_to_string(passed2.status))
            }
          }
        }
      }
    }
  }

  match fetch_revision_history(db, pid2) {
    Ok(history) => {
      println("Audit trail for " + pid2 + ":")
      print_history(history)
    },
    Err(e) => eprintln("history error: " + e.message)
  }

}
