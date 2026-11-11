import { words } from './search.ts';

/** Profile's pages (Batch N), as `ProfilePage.swift`. */
export const PROFILE_PAGES = ['account', 'categories', 'appearance', 'writing', 'notifications', 'widgets', 'privacy', 'data', 'help'] as const;
export type ProfilePage = (typeof PROFILE_PAGES)[number];

export const PAGE_TITLES: Record<ProfilePage, string> = {
  account: 'Account & Sync', categories: 'Categories', appearance: 'Appearance', writing: 'Writing & Dictation',
  notifications: 'Reminders & Notifications', widgets: 'Widgets', privacy: 'Privacy & Security', data: 'Your data', help: 'Help & About',
};

export const PAGE_GROUPS: ProfilePage[][] = [['account', 'categories'], ['appearance', 'writing', 'notifications', 'widgets'], ['privacy', 'data', 'help']];

export interface ProfileSetting { title: string; page: ProfilePage | 'profile'; keywords: string; ownerOnly?: boolean }

/** Every setting on the web Profile, so the search field can find any of them. */
export const PROFILE_SETTINGS: ProfileSetting[] = [
  { title: 'Name', page: 'profile', keywords: 'edit profile your name greeting' },
  { title: 'Profile picture', page: 'profile', keywords: 'avatar photo picture folio avatars remove' },
  { title: 'Sync now', page: 'account', keywords: 'sync status offline up to date' },
  { title: 'Devices', page: 'account', keywords: 'devices sessions browsers sign out other' },
  { title: 'Invite a friend', page: 'account', keywords: 'invite code friend', ownerOnly: true },
  { title: 'Install on your phone', page: 'account', keywords: 'install app home screen pwa' },
  { title: 'Sign out', page: 'account', keywords: 'sign out log out' },
  { title: 'Delete account', page: 'account', keywords: 'delete account remove close' },
  { title: 'Categories', page: 'categories', keywords: 'categories colours tags labels' },
  { title: 'Theme', page: 'appearance', keywords: 'theme dark light mode system appearance' },
  { title: 'Writing font', page: 'appearance', keywords: 'font serif sans new york typeface' },
  { title: 'First day of week', page: 'appearance', keywords: 'week monday sunday calendar start' },
  { title: 'Celebrations', page: 'appearance', keywords: 'celebrations animation bloom sparkle motion' },
  { title: 'Default category', page: 'writing', keywords: 'default category new entries tasks' },
  { title: 'Photo tiles on calendar', page: 'writing', keywords: 'photo tiles calendar pictures' },
  { title: 'Dictation and writing tools', page: 'writing', keywords: 'dictation voice microphone writing tools intelligence' },
  { title: 'Task reminders', page: 'notifications', keywords: 'reminders remind notifications tasks alerts memories on this day' },
  { title: 'Widgets', page: 'widgets', keywords: 'widgets home screen lock screen' },
  { title: 'Trusted browser', page: 'privacy', keywords: 'trust browser forget unlock lock privacy security' },
  { title: 'Recently Deleted', page: 'data', keywords: 'recently deleted trash bin restore' },
  { title: 'Export as JSON + photos', page: 'data', keywords: 'export json zip backup download' },
  { title: 'Export PDF', page: 'data', keywords: 'pdf print book export' },
  { title: 'What do the marks mean?', page: 'help', keywords: 'marks key dots legend calendar' },
  { title: 'Keyboard shortcuts', page: 'help', keywords: 'keyboard shortcuts keys' },
  { title: 'Show the welcome again', page: 'help', keywords: 'welcome tour intro' },
  { title: 'Support & FAQ', page: 'help', keywords: 'support faq help questions contact' },
  { title: 'Privacy Policy', page: 'help', keywords: 'privacy policy legal' },
  { title: 'Terms of Use', page: 'help', keywords: 'terms legal conditions' },
  { title: 'Company details', page: 'help', keywords: 'company imprint business address soul archive' },
  { title: 'Version', page: 'help', keywords: 'version build about' },
];

/** Settings whose title or keywords start with every typed word (same words as diary search). */
export function searchSettings(query: string, canInvite: boolean, settings = PROFILE_SETTINGS): ProfileSetting[] {
  const terms = words(query);
  if (!terms.length) return [];
  return settings.filter((s) => {
    if (s.ownerOnly && !canInvite) return false;
    const own = words(`${s.title} ${s.keywords}`);
    return terms.every((t) => own.some((w) => w.startsWith(t)));
  });
}
