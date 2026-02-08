ALTER TABLE items ADD COLUMN ocr_text TEXT;
ALTER TABLE items ADD COLUMN ocr_status INTEGER NOT NULL DEFAULT 0;
ALTER TABLE items ADD COLUMN ocr_retry_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE items ADD COLUMN ocr_next_retry_at INTEGER NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_items_ocr_status ON items(ocr_status, last_copy_time_ms DESC);
CREATE INDEX IF NOT EXISTS idx_items_ocr_retry ON items(ocr_status, ocr_next_retry_at) WHERE ocr_status = 0;

PRAGMA user_version = 4;
