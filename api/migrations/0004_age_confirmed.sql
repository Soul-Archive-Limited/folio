-- Accounts are for adults (Batch L): a new account records when its owner confirmed being 18 or
-- older and accepting the Terms and Privacy Policy. Existing accounts keep NULL (they predate it).
ALTER TABLE users ADD COLUMN age_confirmed_at INTEGER;
-- An OAuth round trip that may create an account carries whether the box was ticked.
ALTER TABLE oauth_states ADD COLUMN adult INTEGER NOT NULL DEFAULT 0;
