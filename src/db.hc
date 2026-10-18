import "sqlite"

pub fun schema_sql() : string {
  "CREATE TABLE IF NOT EXISTS schema_migrations (" +
  "  version    INTEGER PRIMARY KEY," +
  "  applied_at TEXT NOT NULL DEFAULT (datetime('now'))" +
  ");" +
  "INSERT OR IGNORE INTO schema_migrations(version) VALUES (1);"
}

pub fun init_db(db) => sqlite_exec_batch(db, schema_sql())
