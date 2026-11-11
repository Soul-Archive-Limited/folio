#!/bin/sh
# Empties the LOCAL D1 (wrangler dev's .wrangler state) so the e2e run starts with no review
# account and no rate limits. --local only: it can never touch the deployed database.
set -e
cd "$(dirname "$0")/../api"
for t in rate_limits deletions_log link_requests key_envelopes blobs records handoff_codes oauth_states verification_codes sessions accounts invites users; do
  npx wrangler d1 execute folio-db --local --command "DELETE FROM $t" >/dev/null 2>&1 || true
done
echo "local D1 emptied"
