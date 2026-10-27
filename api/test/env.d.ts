import type { Env as FolioEnv } from '../src/env';

// `env` from cloudflare:test is typed as Cloudflare.Env: give it the Worker's bindings.
declare global {
  namespace Cloudflare {
    interface Env extends FolioEnv {
      TEST_MIGRATIONS: import('cloudflare:test').D1Migration[];
    }
  }
}
