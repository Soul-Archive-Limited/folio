-- Folio schema (SPEC §10.1, §10.3). The server holds ciphertext and the minimum metadata:
-- record id, type, version, client updatedAt, deleted flag, size, and the account email.

CREATE TABLE users (
  id            TEXT PRIMARY KEY,
  email         TEXT,
  created_at    INTEGER NOT NULL,
  next_version  INTEGER NOT NULL DEFAULT 0,  -- per-user monotonic sync version
  record_count  INTEGER NOT NULL DEFAULT 0,  -- quota: 50,000 records
  blob_bytes    INTEGER NOT NULL DEFAULT 0,  -- quota: 1 GB of photos
  deleting      INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX users_email ON users (email);

-- One row per sign-in method linked to a user.
CREATE TABLE accounts (
  id                 TEXT PRIMARY KEY,
  user_id            TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  provider           TEXT NOT NULL,          -- apple | google | email
  provider_user_id   TEXT NOT NULL,          -- Apple/Google `sub`, or the email
  email              TEXT,
  refresh_token_enc  TEXT,                   -- Apple refresh token, AES-GCM with a Worker secret (for revocation)
  created_at         INTEGER NOT NULL,
  UNIQUE (provider, provider_user_id)
);
CREATE INDEX accounts_user ON accounts (user_id);

-- A session is one signed-in device or browser. Only the SHA-256 of the token is stored.
CREATE TABLE sessions (
  id               TEXT PRIMARY KEY,
  user_id          TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  token_hash       TEXT NOT NULL UNIQUE,
  device_name      TEXT NOT NULL,
  platform         TEXT NOT NULL,            -- ios | web
  created_at       INTEGER NOT NULL,
  last_seen_at     INTEGER NOT NULL,
  expires_at       INTEGER NOT NULL,
  reauth_at        INTEGER                    -- last fresh sign-in on this session (delete account)
);
CREATE INDEX sessions_user ON sessions (user_id);

CREATE TABLE verification_codes (
  id          TEXT PRIMARY KEY,
  email       TEXT NOT NULL,
  code_hash   TEXT NOT NULL,                  -- HMAC-SHA256(pepper, email|code)
  attempts    INTEGER NOT NULL DEFAULT 0,
  created_at  INTEGER NOT NULL,
  expires_at  INTEGER NOT NULL
);
CREATE INDEX verification_codes_email ON verification_codes (email);

-- OAuth round trips (state, PKCE verifier, nonce) and the iOS one-time handoff codes.
CREATE TABLE oauth_states (
  state_hash      TEXT PRIMARY KEY,
  provider        TEXT NOT NULL,
  platform        TEXT NOT NULL,
  code_verifier   TEXT,
  nonce           TEXT,
  app_challenge   TEXT,                       -- iOS: SHA-256 of the app's own verifier
  reauth_session  TEXT,
  expires_at      INTEGER NOT NULL
);
CREATE TABLE handoff_codes (
  code_hash       TEXT PRIMARY KEY,
  user_id         TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  app_challenge   TEXT NOT NULL,
  is_new          INTEGER NOT NULL,
  reauth_session  TEXT,
  expires_at      INTEGER NOT NULL
);

-- Encrypted records (SPEC §10.3, §10.5). `ciphertext` and `nonce` are base64.
CREATE TABLE records (
  user_id            TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  id                 TEXT NOT NULL,
  type               TEXT NOT NULL,
  version            INTEGER NOT NULL,
  ciphertext         TEXT NOT NULL,
  nonce              TEXT NOT NULL,
  client_updated_at  INTEGER NOT NULL,
  deleted            INTEGER NOT NULL DEFAULT 0,
  size               INTEGER NOT NULL,
  PRIMARY KEY (user_id, id)
);
CREATE INDEX records_user_version ON records (user_id, version);

-- Encrypted photo renditions in R2 at u/<userId>/<blobId>.
CREATE TABLE blobs (
  user_id     TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  id          TEXT NOT NULL,
  size        INTEGER NOT NULL,
  created_at  INTEGER NOT NULL,
  PRIMARY KEY (user_id, id)
);

-- Wrapped copies of the data key; the server can never unwrap them (SPEC §10.3–10.4).
CREATE TABLE key_envelopes (
  user_id     TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  kind        TEXT NOT NULL,                  -- recovery
  envelope    TEXT NOT NULL,
  created_at  INTEGER NOT NULL,
  PRIMARY KEY (user_id, kind)
);

-- "Link a browser or device" (SPEC §10.4): 5-minute requests, the server only relays.
CREATE TABLE link_requests (
  id                 TEXT PRIMARY KEY,
  user_id            TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  session_id         TEXT NOT NULL,
  public_key         TEXT NOT NULL,
  device_name        TEXT NOT NULL,
  platform           TEXT NOT NULL,
  sender_public_key  TEXT,
  envelope           TEXT,
  envelope_nonce     TEXT,
  created_at         INTEGER NOT NULL,
  expires_at         INTEGER NOT NULL
);
CREATE INDEX link_requests_user ON link_requests (user_id);

-- Fixed-window counters for limits longer than a minute (SPEC §10.7).
CREATE TABLE rate_limits (
  key           TEXT PRIMARY KEY,
  window_start  INTEGER NOT NULL,
  count         INTEGER NOT NULL
);

-- Only a keyed hash of the user id and the time (SPEC §10.6).
CREATE TABLE deletions_log (
  id_hash     TEXT NOT NULL,
  deleted_at  INTEGER NOT NULL
);
