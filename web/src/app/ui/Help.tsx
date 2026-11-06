import { Sheet } from './common.tsx';

/** "What do the marks mean?" (SPEC §6.2), the iPhone's key drawn with the web's own cells. */
export function MarksKey({ onClose }: { onClose: () => void }) {
  const rows: [React.ReactNode, string][] = [
    [<span className="key-cell photo-key"><span className="n">12</span></span>, 'A page with a photo: its latest photo fills the day.'],
    [<span className="key-cell"><span className="n">12</span><span className="dots"><i style={{ ['--c' as string]: 'var(--cat-indigo)' }} /><i style={{ ['--c' as string]: 'var(--cat-rose)' }} /></span></span>, 'Pages without photos: one dot per category, up to three.'],
    [<span className="key-cell"><span className="n">12</span><span className="ring" /></span>, 'Tasks still to do on that day.'],
    [<span className="key-cell"><span className="n">12</span><span className="ring done" /></span>, 'Every task on that day is done.'],
    [<span className="key-cell today"><span className="n">12</span></span>, 'Today.'],
    [<span className="key-cell selected"><span className="n">12</span></span>, 'The day you picked.'],
  ];
  return (
    <Sheet label="What do the marks mean?" onClose={onClose} scrim>
      <h2 className="title2" style={{ marginTop: 0 }}>What do the marks mean?</h2>
      <ul className="key-list">{rows.map(([cell, text], i) => <li key={i}>{cell}<span>{text}</span></li>)}</ul>
    </Sheet>
  );
}

const mac = typeof navigator !== 'undefined' && /Mac|iPhone|iPad/.test(navigator.platform || navigator.userAgent);
const mod = mac ? '⌘' : 'Ctrl';
export const SHORTCUTS: [string[], string][] = [
  [['N'], 'New entry (for the selected day)'],
  [['T'], 'New task'],
  [['/'], 'Search'],
  [[mod, 'K'], 'Search'],
  [['1'], 'Calendar'], [['2'], 'Journal'], [['3'], 'To-do'], [['4'], 'Profile'],
  [['←', '→', '↑', '↓'], 'Move between days (in the calendar)'],
  [['['], 'Previous month'], [[']'], 'Next month'],
  [['G'], 'Go to today'],
  [[mod, 'Enter'], 'Save (in the composer)'],
  [['Esc'], 'Close a sheet or menu'],
  [['?'], 'This list'],
];

/** Keyboard shortcuts (Batch L), also opened with "?". */
export function Shortcuts({ onClose }: { onClose: () => void }) {
  return (
    <Sheet label="Keyboard shortcuts" onClose={onClose} scrim>
      <h2 className="title2" style={{ marginTop: 0 }}>Keyboard shortcuts</h2>
      <dl className="shortcuts">
        {SHORTCUTS.map(([keys, what]) => (
          <div key={what + keys.join()}><dt>{keys.map((k) => <kbd key={k}>{k}</kbd>)}</dt><dd>{what}</dd></div>
        ))}
      </dl>
      <p className="fine">Shortcuts are off while you type in a field.</p>
    </Sheet>
  );
}
