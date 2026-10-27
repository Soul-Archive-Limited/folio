// @ts-check
import { defineConfig } from 'astro/config';
import react from '@astrojs/react';
import sitemap from '@astrojs/sitemap';

// Static site on Cloudflare Pages (SPEC §11.1). /app (Phase 12) and /api stay out of the sitemap.
export default defineConfig({
  site: 'https://folio.devilsense.com',
  output: 'static',
  trailingSlash: 'never',
  build: { format: 'file', inlineStylesheets: 'never' },
  integrations: [react(), sitemap({ filter: (page) => !page.includes('/404') })],
});
