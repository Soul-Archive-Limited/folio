/** Line icons in the spirit of SF Symbols (the web has no SF Symbols). */
const PATHS: Record<string, string> = {
  calendar: 'M4 7a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2zM4 10h16M8 3v4M16 3v4M8 14h.01M12 14h.01M16 14h.01M8 17.5h.01M12 17.5h.01',
  journal: 'M6 3h10a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6zM6 3a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2M9 8h6M9 12h6M9 16h4M20 6v14',
  todo: 'M4 6.5l1.5 1.5L8.5 5M4 13.5l1.5 1.5 3-3M12 7h8M12 14h8M5.5 19.5h.01M12 19.5h8',
  profile: 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 12.5a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM6.3 18.2a6.5 6.5 0 0 1 11.4 0',
  plus: 'M12 5v14M5 12h14',
  close: 'M6 6l12 12M18 6L6 18',
  chevronDown: 'M6 9l6 6 6-6',
  chevronRight: 'M9 6l6 6-6 6',
  chevronLeft: 'M15 6l-6 6 6 6',
  filter: 'M4 6h16M7 12h10M10 18h4',
  photo: 'M4 7a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2zM8.5 10.5a1.5 1.5 0 1 0 0-.01M20 15l-4.5-4.5L7 19',
  camera: 'M4 8a2 2 0 0 1 2-2h2l1.5-2h5L16 6h2a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2zM12 16a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7z',
  tag: 'M3 12V4h8l10 10-8 8zM7.5 7.5h.01',
  mic: 'M12 3a3 3 0 0 1 3 3v6a3 3 0 0 1-6 0V6a3 3 0 0 1 3-3zM5 11a7 7 0 0 0 14 0M12 18v3',
  sparkle: 'M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8zM19 16l.7 1.8 1.8.7-1.8.7L19 21l-.7-1.8-1.8-.7 1.8-.7z',
  textformat: 'M4 18l5-12 5 12M5.8 14h6.4M15 18v-7M15 14.5a3 3 0 1 1 6 0 3 3 0 0 1-6 0',
  more: 'M5 12h.01M12 12h.01M19 12h.01',
  trash: 'M4 7h16M10 11v6M14 11v6M6 7l1 12a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-12M9 7V4h6v3',
  restore: 'M4 12a8 8 0 1 0 2.4-5.7M4 4v4h4',
  edit: 'M4 20h4L19 9l-4-4L4 16zM13.5 6.5l4 4',
  copy: 'M9 9h10v10H9zM5 15V5h10',
  share: 'M12 15V3M8 7l4-4 4 4M5 12v7a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-7',
  check: 'M5 12.5l4.5 4.5L19 7',
  globe: 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM3 12h18M12 3c2.5 2.6 3.8 5.6 3.8 9s-1.3 6.4-3.8 9c-2.5-2.6-3.8-5.6-3.8-9S9.5 5.6 12 3z',
  iphone: 'M8 3h8a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2zM11 5.5h2',
  key: 'M14.5 9.5a4 4 0 1 0-1 2.7L21 19.7V22h-3v-2h-2v-2l-2.2-2.2M8.5 8h.01',
  lock: 'M6 11h12v10H6zM8.5 11V7.5a3.5 3.5 0 0 1 7 0V11',
  qr: 'M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h2v2h-2zM18 14h2M14 18h2v2M18 18h2v2',
  signout: 'M15 4h3a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-3M10 16l-4-4 4-4M6 12h10',
  sun: 'M12 16a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4',
  sync: 'M20 11a8 8 0 0 0-14.3-4.3L4 9M4 4v5h5M4 13a8 8 0 0 0 14.3 4.3L20 15M20 20v-5h-5',
  seal: 'M12 3l2.2 1.6 2.7-.2.8 2.6 2.3 1.5-.9 2.5.9 2.5-2.3 1.5-.8 2.6-2.7-.2L12 21l-2.2-1.6-2.7.2-.8-2.6-2.3-1.5.9-2.5-.9-2.5 2.3-1.5.8-2.6 2.7.2zM8.5 12l2.5 2.5 4.5-5',
  pages: 'M7 3h7l5 5v13H7zM14 3v5h5M10 13h6M10 17h6',
  bold: 'M7 4h6a4 4 0 0 1 0 8H7zM7 12h7a4 4 0 0 1 0 8H7z',
  italic: 'M10 4h8M6 20h8M14 4l-4 16',
  underline: 'M7 4v7a5 5 0 0 0 10 0V4M5 20h14',
  strike: 'M5 12h14M16 6.5A4 4 0 0 0 12.5 4h-1a3.5 3.5 0 0 0-1 6.9M8 17.5a4 4 0 0 0 3.5 2.5h1a3.5 3.5 0 0 0 3-5',
  highlight: 'M9 15l-4 4h6l1.5-1.5M9 15l7.5-7.5 3 3L12 18M9 15l3 3M14 5l5 5',
  heading: 'M6 4v16M18 4v16M6 12h12',
  bullets: 'M9 6h11M9 12h11M9 18h11M4.5 6h.01M4.5 12h.01M4.5 18h.01',
  numbers: 'M10 6h10M10 12h10M10 18h10M4 4.5h1.5V9M4 9h3M4 14.5a1.5 1.5 0 1 1 2.5 1.2L4 19.5h3',
  checklist: 'M4 5h5v5H4zM5.5 7.5l1 1 2-2M4 14h5v5H4zM13 7.5h7M13 16.5h7',
  quote: 'M7 7H5a2 2 0 0 0-2 2v2a2 2 0 0 0 2 2h2v2a3 3 0 0 1-3 3M17 7h-2a2 2 0 0 0-2 2v2a2 2 0 0 0 2 2h2v2a3 3 0 0 1-3 3',
  devices: 'M3 6a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v6M3 6v8h9M7 18h5M17 10h3a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1h-3a1 1 0 0 1-1-1v-8a1 1 0 0 1 1-1z',
  search: 'M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14zM20 20l-4-4',
};

export function Icon({ name, small, label }: { name: keyof typeof PATHS | string; small?: boolean; label?: string }) {
  return (
    <svg className={small ? 'i sm' : 'i'} viewBox="0 0 24 24" aria-hidden={label ? undefined : true} role={label ? 'img' : undefined} aria-label={label}>
      <path d={PATHS[name] ?? ''} />
    </svg>
  );
}

/** The app mark: a rounded page with an ember dot (SPEC §3.10). */
export function Mark({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 64 64" aria-hidden="true">
      <rect x="6" y="6" width="52" height="52" rx="16" fill="#16161a" />
      <rect x="19" y="16" width="26" height="32" rx="5" fill="#f5f3ef" />
      <circle cx="40" cy="21" r="4.5" fill="#ff7a45" />
    </svg>
  );
}

export const AppleLogo = () => (
  <svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M16.4 12.6c0-2.4 2-3.5 2-3.6-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.2-2.8.8-3.5.8-.7 0-1.8-.8-3-.8-1.5 0-3 .9-3.8 2.3-1.6 2.8-.4 7 1.2 9.3.8 1.1 1.7 2.4 2.9 2.3 1.2 0 1.6-.7 3-.7s1.8.7 3 .7c1.3 0 2.1-1.1 2.8-2.3.9-1.3 1.3-2.6 1.3-2.6s-2.5-1-2.5-3.6zM14.1 5.6c.6-.8 1.1-1.8 1-2.9-.9 0-2.1.6-2.7 1.4-.6.7-1.1 1.8-1 2.8 1 .1 2.1-.5 2.7-1.3z" /></svg>
);

export const GoogleLogo = () => (
  <svg viewBox="0 0 24 24" aria-hidden="true">
    <path fill="#4285F4" d="M22.6 12.3c0-.8-.1-1.6-.2-2.3H12v4.4h6c-.3 1.4-1 2.6-2.2 3.4v2.8h3.6c2.1-2 3.2-4.9 3.2-8.3z" />
    <path fill="#34A853" d="M12 23c3 0 5.5-1 7.4-2.7l-3.6-2.8c-1 .7-2.3 1.1-3.8 1.1-2.9 0-5.4-2-6.3-4.6H2v2.9A11 11 0 0 0 12 23z" />
    <path fill="#FBBC05" d="M5.7 14c-.2-.7-.4-1.4-.4-2s.1-1.4.4-2V7.1H2A11 11 0 0 0 1 12c0 1.8.4 3.4 1.1 4.9z" />
    <path fill="#EA4335" d="M12 5.4c1.6 0 3.1.6 4.2 1.7l3.2-3.2A11 11 0 0 0 2 7.1L5.7 10c.9-2.7 3.4-4.6 6.3-4.6z" />
  </svg>
);
