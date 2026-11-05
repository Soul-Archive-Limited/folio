-- Invite-only sign-up (Batch J). Codes are stored only as an HMAC (OTP_PEPPER); the owner sees
-- a code once, when it's made, plus its last two characters to tell invites apart.
CREATE TABLE invites (
  id          TEXT PRIMARY KEY,
  code_hash   TEXT NOT NULL UNIQUE,
  hint        TEXT NOT NULL,
  created_by  TEXT NOT NULL,
  created_at  INTEGER NOT NULL,
  expires_at  INTEGER NOT NULL,
  used_by     TEXT,
  used_at     INTEGER,
  revoked_at  INTEGER
);
CREATE INDEX invites_by_creator ON invites (created_by, created_at);

-- An OAuth round trip that may create an account carries the invite's hash, never the code.
ALTER TABLE oauth_states ADD COLUMN invite_hash TEXT;
