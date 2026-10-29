-- Batch F: a name the person gives a device, sealed with their Data Key (AES-GCM, associated
-- data `sessionId|deviceLabel|userId`). The server can't read it; it goes with the session.
ALTER TABLE sessions ADD COLUMN label_ciphertext TEXT;
ALTER TABLE sessions ADD COLUMN label_nonce TEXT;
