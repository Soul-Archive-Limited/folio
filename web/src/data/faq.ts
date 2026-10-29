import { site } from '../config/site';

/** FAQ answers shared by the home page and Support (SPEC §11.2, §14.3). Plain HTML strings. */
export const faq = {
  readDiary: {
    q: 'Can you read my diary?',
    a: 'No. Without an account your diary never leaves your iPhone. With sync on, everything you write — entries, photos, tasks and categories — is encrypted on your device before it’s uploaded, with a key only your devices hold. Our servers store data they can’t read, so Soul Archive Ltd can’t read your diary, and can’t hand it to anyone else either.',
  },
  account: {
    q: 'Do I need an account?',
    a: 'Not on iPhone: Folio works fully without one, offline too. An account is only for syncing with the web and other devices, and you can add one any time. On the web, Get started creates one with Apple, Google or an email code.',
  },
  lostPhone: {
    q: 'What if I lose my iPhone?',
    a: 'With sync on, your diary comes back on a new iPhone through iCloud Keychain, or with your recovery key — a code you save when you turn sync on. Because the diary is end-to-end encrypted, we can’t recover it for you: if you lose every device and the recovery key, it can’t be read. Without sync, your diary lives only on that iPhone, so export it from Profile → Your data now and then.',
  },
  recentlyDeleted: {
    q: 'What happens when I delete something?',
    a: 'Entries (with their photos), tasks and categories go to Recently Deleted for 30 days, so you can restore them to the same day. After 30 days they’re deleted for good. You can also restore or delete them sooner from Profile → Your data → Recently Deleted.',
  },
  pastDays: {
    q: 'Can I write for days in the past?',
    a: 'Yes, any day back to 1900. It’s made for moving old paper diaries in: pick the date, write or dictate, add photos.',
  },
  dictation: {
    q: 'Does dictation send my voice anywhere?',
    a: 'No. Dictation and the ✦ writing tools run on your iPhone with Apple’s on-device models. Audio isn’t stored and nothing is sent to us or anyone else.',
  },
  web: {
    q: 'Can I use Folio on the web?',
    a: 'Yes, at <a href="/app">folio.devilsense.com/app</a>. Sign in, then unlock your diary by scanning a code with Folio on your iPhone (or with your recovery key). The key travels from phone to browser end-to-end encrypted, so it never reaches us in a form we can read.',
  },
  export: {
    q: 'Can I get my diary out?',
    a: 'Yes. Profile → Your data → Export makes a JSON file of everything plus a zip of your photos, right on your iPhone.',
  },
  android: {
    q: 'Is there an Android app?',
    a: 'Not yet. Folio is for iPhone and iPad, and works in any modern browser on the web.',
  },
  recoveryKey: {
    q: 'What is the recovery key?',
    a: 'When you turn on sync, Folio shows a 26-character code. It’s the only way to unlock your diary on a new device if your other devices are gone. Save it somewhere safe — a password manager, or printed in a drawer. We never see it and can’t send it to you.',
  },
  timeZones: {
    q: 'What happens when I travel across time zones?',
    a: 'Nothing moves. A Folio day is a calendar date, not a moment in time, so Tuesday’s page stays on Tuesday whether you wrote it in Lisbon or Singapore.',
  },
  free: {
    q: 'What does Folio cost?',
    a: 'Nothing. Folio is free, with no ads, no in-app purchases and no tracking.',
  },
  streaks: {
    q: 'Will Folio nag me to write?',
    a: 'No. There are no streaks, badges or reminders to keep up. Write when you want to; quiet weeks are fine.',
  },
  shared: {
    q: 'Can two people share a diary?',
    a: 'Not at the moment: every Folio diary is private to one person. Two people can each keep their own — same trip, two diaries — and neither can read the other’s.',
  },
  who: {
    q: 'Who makes Folio?',
    a: `Soul Archive Ltd, a small company in England. The code is open source on <a href="${site.githubUrl}">GitHub</a>, so you can check how your diary is handled.`,
  },
};
