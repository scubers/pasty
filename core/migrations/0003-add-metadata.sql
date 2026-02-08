ALTER TABLE items ADD COLUMN metadata TEXT NOT NULL DEFAULT '';
PRAGMA user_version = 3;
