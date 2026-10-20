-- Exported from an actual Drift-created schema v1. No user data.
PRAGMA user_version = 1;

CREATE TABLE "day_notes" ("id" TEXT NOT NULL, "date" TEXT NOT NULL, "content" TEXT NOT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "revision" INTEGER NOT NULL CHECK (revision > 0), "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));

CREATE TABLE "settings_entries" ("key" TEXT NOT NULL, "value" TEXT NOT NULL, PRIMARY KEY ("key"));

CREATE UNIQUE INDEX one_active_note_per_date ON day_notes(date) WHERE is_deleted = 0;
