# shared

Files used by both the iOS app and the web app so they behave identically:

- `markdown-fixtures.json` — round-trip test vectors for the Markdown codec (SPEC §5.1). Added in Phase 2.
- `crypto-vectors.json` — AES-GCM / HKDF / X25519 test vectors (SPEC §10.3). Added in Phase 2.
- API types (JSON Schema generated from the Worker's zod schemas). Added in Phase 9.
