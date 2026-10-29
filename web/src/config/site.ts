/**
 * Every call to action on the site comes from here (Batch D). A button only renders when its
 * value is set, so nothing dead ships. Fill these in as each one goes live.
 */
export const site = {
  name: 'Folio',
  url: 'https://folio.devilsense.com',
  /** Public TestFlight link, e.g. https://testflight.apple.com/join/XXXXXXXX. Empty = hidden. */
  testflightUrl: '',
  /** App Store listing. Empty = hidden. */
  appStoreUrl: '',
  /** True once the web app at /app is live (Phase 12). */
  webAppLive: true,
  githubUrl: 'https://github.com/Soul-Archive-Limited/folio',
  supportEmail: 'support@devilsense.com',
  privacyEmail: 'privacy@devilsense.com',
  company: {
    name: 'Soul Archive Ltd',
    number: '16186654',
    office: '71-75 Shelton Street, Covent Garden, London, WC2H 9JQ',
  },
} as const;

export type Cta = { label: string; href: string; primary?: boolean; external?: boolean };

/** The hero's buttons: store links when they exist, otherwise source + privacy. */
export function heroCtas(): Cta[] {
  const ctas: Cta[] = [];
  if (site.appStoreUrl) ctas.push({ label: 'Download on the App Store', href: site.appStoreUrl, primary: true, external: true });
  else if (site.testflightUrl) ctas.push({ label: 'Join the TestFlight', href: site.testflightUrl, primary: true, external: true });
  if (site.webAppLive) ctas.push({ label: 'Open in browser', href: '/app', primary: ctas.length === 0 });
  if (ctas.length === 0) {
    ctas.push({ label: 'View the source on GitHub', href: site.githubUrl, primary: true, external: true });
    ctas.push({ label: 'How your privacy works', href: '/#privacy' });
  }
  return ctas;
}
