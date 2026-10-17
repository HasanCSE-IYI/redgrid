-- RedGrid Cloudflare D1 Database Schema
-- Execute with: wrangler d1 execute redgrid-db --file=./schema.sql --remote

CREATE TABLE IF NOT EXISTS donors (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  blood_group TEXT NOT NULL,
  gender TEXT NOT NULL DEFAULT 'MALE',
  phone TEXT NOT NULL UNIQUE,
  consent_to_share INTEGER NOT NULL DEFAULT 0,
  district TEXT NOT NULL,
  area TEXT NOT NULL,
  last_donation_date TEXT,
  total_donations INTEGER NOT NULL DEFAULT 0,
  notes TEXT,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS donation_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  donor_phone TEXT NOT NULL,
  donation_date TEXT NOT NULL,
  created_at TEXT NOT NULL,
  UNIQUE (donor_phone, donation_date)
);

CREATE INDEX IF NOT EXISTS idx_donors_phone ON donors (phone);
CREATE INDEX IF NOT EXISTS idx_donors_updated ON donors (updated_at);
CREATE INDEX IF NOT EXISTS idx_donors_is_deleted ON donors (is_deleted);
CREATE INDEX IF NOT EXISTS idx_logs_phone_date ON donation_logs (donor_phone, donation_date);
CREATE INDEX IF NOT EXISTS idx_logs_created ON donation_logs (created_at);
