import "sqlite"

pub struct StoredRevision {
  version: string,
  status: string,
  canonical_hml: string
}

pub fun schema_sql() : string {
  "PRAGMA foreign_keys = ON;" +
  "CREATE TABLE IF NOT EXISTS schema_migrations (" +
  "  version    INTEGER PRIMARY KEY," +
  "  applied_at TEXT NOT NULL DEFAULT (datetime('now'))" +
  ");" +
  "CREATE TABLE IF NOT EXISTS proposals (" +
  "  proposal_id    TEXT PRIMARY KEY," +
  "  active_version TEXT NOT NULL," +
  "  status         TEXT NOT NULL," +
  "  created_at     TEXT NOT NULL DEFAULT (datetime('now'))," +
  "  updated_at     TEXT NOT NULL DEFAULT (datetime('now'))" +
  ");" +
  "CREATE TABLE IF NOT EXISTS proposal_revisions (" +
  "  id            INTEGER PRIMARY KEY," +
  "  proposal_id   TEXT NOT NULL REFERENCES proposals(proposal_id) ON DELETE CASCADE," +
  "  version       TEXT NOT NULL," +
  "  status        TEXT NOT NULL," +
  "  canonical_hml TEXT NOT NULL," +
  "  recorded_at   TEXT NOT NULL DEFAULT (datetime('now'))," +
  "  UNIQUE(proposal_id, version)" +
  ");" +
  "CREATE INDEX IF NOT EXISTS idx_proposal_revisions_history " +
  "ON proposal_revisions(proposal_id, id);" +
  "INSERT OR IGNORE INTO schema_migrations(version) VALUES (1);" +
  "INSERT OR IGNORE INTO schema_migrations(version) VALUES (2);"
}

pub fun init_db(db) => sqlite_exec_batch(db, schema_sql())

pub fun insert_initial_revision(db: Db, proposal_id: string, version: string, status: string, canonical_hml: string) {
  match sqlite_exec_p(
    db,
    "INSERT INTO proposals(proposal_id, active_version, status) VALUES (?, ?, ?)",
    [
      param(proposal_id),
      param(version),
      param(status)
    ]
  ) {
    Err(error) => Err(error),
    Ok(_) => sqlite_exec_p(
      db,
      "INSERT INTO proposal_revisions(proposal_id, version, status, canonical_hml) " +
      "VALUES (?, ?, ?, ?)",
      [
        param(proposal_id),
        param(version),
        param(status),
        param(canonical_hml)
      ]
    )
  }
}

pub fun create_stored_proposal(db: Db, proposal_id: string, version: string, status: string, canonical_hml: string) {
  with_transaction(db, (transaction_db) =>
    insert_initial_revision(transaction_db, proposal_id, version, status, canonical_hml)
  )
}

pub fun update_active_revision(db: Db, proposal_id: string, version: string, status: string) {
  match sqlite_exec_p(
    db,
    "UPDATE proposals " +
    "SET active_version = ?, status = ?, updated_at = datetime('now') " +
    "WHERE proposal_id = ?",
    [
      param(version),
      param(status),
      param(proposal_id)
    ]
  ) {
    Err(error) => Err(error),
    Ok(_) => if sqlite_changes(db) == 1 {
      Ok(true)
    } else {
      Err(SqliteError { code: -1, message: "proposal not found: " + proposal_id })
    }
  }
}

pub fun insert_appended_revision(db: Db, proposal_id: string, version: string, status: string, canonical_hml: string) {
  match sqlite_exec_p(
    db,
    "INSERT INTO proposal_revisions(proposal_id, version, status, canonical_hml) " +
    "VALUES (?, ?, ?, ?)",
    [
      param(proposal_id),
      param(version),
      param(status),
      param(canonical_hml)
    ]
  ) {
    Err(error) => Err(error),
    Ok(_) => update_active_revision(db, proposal_id, version, status)
  }
}

pub fun append_stored_revision(db: Db, proposal_id: string, version: string, status: string, canonical_hml: string) {
  with_transaction(db, (transaction_db) =>
    insert_appended_revision(transaction_db, proposal_id, version, status, canonical_hml)
  )
}

pub fun stored_revision(row: Row) : StoredRevision {
  StoredRevision {
    version: unwrap_maybe_or(row_str(row, 0), ""),
    status: unwrap_maybe_or(row_str(row, 1), ""),
    canonical_hml: unwrap_maybe_or(row_str(row, 2), "")
  }
}

pub fun fetch_active_revision(db: Db, proposal_id: string) {
  match sqlite_query_p(
    db,
    "SELECT r.version, r.status, r.canonical_hml " +
    "FROM proposals p " +
    "JOIN proposal_revisions r " +
    "ON r.proposal_id = p.proposal_id AND r.version = p.active_version " +
    "WHERE p.proposal_id = ?",
    [param(proposal_id)]
  ) {
    Err(error) => Err(error),
    Ok(result) => match result.rows {
      [] => Ok(None),
      [row, .._] => Ok(Some(stored_revision(row)))
    }
  }
}

pub fun fetch_revision_history(db: Db, proposal_id: string) {
  match sqlite_query_p(
    db,
    "SELECT version, status, canonical_hml " +
    "FROM proposal_revisions WHERE proposal_id = ? ORDER BY id",
    [param(proposal_id)]
  ) {
    Err(error) => Err(error),
    Ok(result) => Ok(map(result.rows, stored_revision))
  }
}
