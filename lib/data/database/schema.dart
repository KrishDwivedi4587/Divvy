/// The SQLite schema and its migrations.
///
/// Money is stored as integer minor units (paise), never as REAL. Timestamps
/// are ISO-8601 text; bill dates are `YYYY-MM-DD` text.
///
/// Participants are per-bill snapshots, not references to the People list: the
/// name, initials and totals are copied in when a bill is saved, and
/// `person_id` is only a link back (set to NULL if the person is ever
/// hard-deleted). That is what keeps history intact when a person is renamed
/// or removed.
library;

/// The schema version the app ships with.
const int currentSchemaVersion = 1;

/// Statements that create the version 1 schema from nothing.
const List<String> schemaV1 = [
  '''
CREATE TABLE people (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  color_index INTEGER NOT NULL DEFAULT 0,
  is_self INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  archived_at TEXT
)''',
  // At most one row may be the account holder.
  'CREATE UNIQUE INDEX idx_people_self ON people(is_self) WHERE is_self = 1',
  '''
CREATE TABLE bills (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  merchant TEXT,
  bill_date TEXT NOT NULL,
  created_at TEXT NOT NULL,
  currency TEXT NOT NULL,
  split_mode TEXT NOT NULL,
  receipt_path TEXT,
  ocr_text TEXT,
  payer_participant_id TEXT REFERENCES bill_participants(id) ON DELETE SET NULL,
  items_subtotal INTEGER NOT NULL,
  grand_total INTEGER NOT NULL,
  unassigned_total INTEGER NOT NULL DEFAULT 0
)''',
  '''
CREATE TABLE bill_participants (
  id TEXT PRIMARY KEY,
  bill_id TEXT NOT NULL REFERENCES bills(id) ON DELETE CASCADE,
  person_id TEXT REFERENCES people(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  initials TEXT NOT NULL,
  color_index INTEGER NOT NULL,
  position INTEGER NOT NULL,
  subtotal INTEGER NOT NULL,
  total INTEGER NOT NULL,
  settled_at TEXT
)''',
  '''
CREATE TABLE bill_items (
  id TEXT PRIMARY KEY,
  bill_id TEXT NOT NULL REFERENCES bills(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  unit_price INTEGER NOT NULL,
  line_total INTEGER NOT NULL,
  source TEXT NOT NULL,
  ocr_confidence REAL,
  raw_text TEXT,
  position INTEGER NOT NULL
)''',
  '''
CREATE TABLE item_allocations (
  item_id TEXT NOT NULL REFERENCES bill_items(id) ON DELETE CASCADE,
  participant_id TEXT NOT NULL REFERENCES bill_participants(id) ON DELETE CASCADE,
  PRIMARY KEY (item_id, participant_id)
)''',
  '''
CREATE TABLE bill_adjustments (
  id TEXT PRIMARY KEY,
  bill_id TEXT NOT NULL REFERENCES bills(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  kind TEXT NOT NULL,
  mode TEXT NOT NULL,
  value INTEGER NOT NULL,
  position INTEGER NOT NULL,
  base TEXT NOT NULL,
  is_negative INTEGER NOT NULL DEFAULT 0
)''',
  '''
CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)''',
  'CREATE INDEX idx_bills_date ON bills(bill_date DESC, created_at DESC)',
  'CREATE INDEX idx_participants_bill ON bill_participants(bill_id)',
  'CREATE INDEX idx_participants_person ON bill_participants(person_id)',
  'CREATE INDEX idx_items_bill ON bill_items(bill_id)',
  'CREATE INDEX idx_adjustments_bill ON bill_adjustments(bill_id)',
];

/// One step from `version - 1` to `version`. Migrations run in order, inside
/// the upgrade transaction, and must never drop user data.
class Migration {
  const Migration(this.version, this.statements);

  final int version;
  final List<String> statements;
}

/// Migrations after version 1. Empty today; each future schema change adds one
/// here and raises [currentSchemaVersion].
const List<Migration> migrations = [];
