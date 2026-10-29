/**
 * Every call to action on the site comes from here (Batch D, Batch H). A button only renders
 * when its value is set, so nothing dead ships. Fill these in as each one goes live.
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

/** The main navigation (Batch H). */
export const navLinks = [
  { href: '/features', label: 'Features' },
  { href: '/how-it-works', label: 'How it works' },
  { href: '/security', label: 'Privacy' },
  { href: '/about', label: 'About' },
  { href: '/faq', label: 'FAQ' },
] as const;

/** Sign in and Get started both open the web app: the same Apple / Google / email flow creates the account. */
export const account = site.webAppLive
  ? { signIn: '/app', getStarted: '/app' }
  : { signIn: '', getStarted: '/download' };

/** The store button, when there is one: App Store first, then TestFlight. */
export function storeCta(): Cta | null {
  if (site.appStoreUrl) return { label: 'Download on the App Store', href: site.appStoreUrl, external: true };
  if (site.testflightUrl) return { label: 'Join the TestFlight', href: site.testflightUrl, external: true };
  return null;
}
