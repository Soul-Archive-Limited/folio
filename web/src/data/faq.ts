import { site } from '../config/site';

/** FAQ answers shared by the home page and Support (SPEC §11.2, §14.3). Plain HTML strings. */
export const faq = {
  readDiary: {
    q: 'Can you read my diary?',
    a: 'No. Without an account your diary never leaves your iPhone. When sync arrives, everything you write — entries, photos, tasks and categories — is encrypted on your device before it’s uploaded, with a key only your devices hold. Our servers store data they can’t read, so Soul Archive Ltd can’t read your diary, and can’t hand it to anyone else either.',
  },
  account: {
    q: 'Do I need an account?',
    a: 'No. Folio works fully on your iPhone without an account, offline too. An account will only be needed for syncing with the web and a second device, and you can add one any time.',
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
    a: 'A web version is on the way. You’ll unlock it by scanning a code with your iPhone, so your encryption key never touches our servers.',
  },
  export: {
    q: 'Can I get my diary out?',
    a: 'Yes. Profile → Your data → Export makes a JSON file of everything plus a zip of your photos, right on your iPhone.',
  },
  android: {
    q: 'Is there an Android app?',
    a: 'Not yet. Folio is for iPhone, with a web version coming.',
  },
  who: {
    q: 'Who makes Folio?',
    a: `Soul Archive Ltd, a small company in England. The code is open source on <a href="${site.githubUrl}">GitHub</a>, so you can check how your diary is handled.`,
  },
};
