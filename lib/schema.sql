-- Nexus v0.2 SQLite Schema

CREATE TABLE IF NOT EXISTS tasks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  assignee TEXT NOT NULL CHECK(assignee IN ('claude','codex','human')),
  priority INTEGER NOT NULL CHECK(priority BETWEEN 1 AND 5),
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK(status IN ('pending','in_progress','review','done','failed','escalated')),
  mode TEXT NOT NULL CHECK(mode IN ('worker','reviewer','sub-conductor')),
  parent_id TEXT REFERENCES tasks(id),
  reviewed_by TEXT CHECK(reviewed_by IN ('claude','codex')),
  review_status TEXT DEFAULT 'pending'
    CHECK(review_status IN ('pending','approved','changes_requested')),
  retry_count INTEGER DEFAULT 0,
  depends TEXT DEFAULT '[]',
  notes TEXT DEFAULT '[]',
  created_at TEXT NOT NULL,
  completed_at TEXT
);

CREATE TABLE IF NOT EXISTS knowledge (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL CHECK(type IN ('gotcha','pattern','decision','anti-pattern')),
  fact TEXT NOT NULL,
  recommendation TEXT DEFAULT '',
  confidence TEXT NOT NULL CHECK(confidence IN ('high','medium','low')),
  source TEXT NOT NULL CHECK(source IN ('claude','codex','human')),
  tags TEXT DEFAULT '[]',
  files TEXT DEFAULT '[]',
  source_task_id TEXT,
  outcome TEXT CHECK(outcome IN ('success','failed','retry')),
  expires_at TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp TEXT NOT NULL,
  event_type TEXT NOT NULL,
  task_id TEXT,
  agent TEXT,
  payload TEXT DEFAULT '{}'
);

CREATE TABLE IF NOT EXISTS dispatches (
  id TEXT PRIMARY KEY,
  timestamp TEXT NOT NULL,
  task_id TEXT NOT NULL,
  mode TEXT NOT NULL,
  model TEXT NOT NULL,
  backend TEXT NOT NULL DEFAULT 'shell',
  prompt_summary TEXT,
  duration_seconds INTEGER,
  exit_code INTEGER,
  failure_type TEXT,
  files_changed TEXT DEFAULT '[]',
  validated INTEGER DEFAULT 0,
  reviewed_by TEXT,
  review_result TEXT
);

CREATE TABLE IF NOT EXISTS usage (
  date TEXT PRIMARY KEY,
  dispatches INTEGER DEFAULT 0,
  duration_seconds INTEGER DEFAULT 0
);
