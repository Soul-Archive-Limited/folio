import { useState } from 'react';
import { SETTINGS_ID, type SettingsData } from '../lib/payloads.ts';
import { AvatarGrid } from './Avatar.tsx';
import { useDiary } from './context.tsx';
import { Icon, Mark } from './Icons.tsx';

const TILES = [3, 9, 12, 16, 20, 24, 27];

/**
 * The first visit in a browser (Batch L), in the iPhone onboarding's voice (SPEC §6.1): a
 * welcome, then — only if the account has no name yet — "What should we call you?" with the
 * Folio avatars and the look, then where things are. One sentence per screen; skippable.
 * Remembered per account in this browser (`folio.welcomed.<userId>`).
 */
export default function Welcome({ onDone }: { onDone: () => void }) {
  const { store, me } = useDiary();
  const settings: SettingsData = store.settings ?? { displayName: '', appearance: 'system', writingFont: 'newYork', createdAt: Date.now() };
  // Decided once: saving a name on step 2 must not turn this into the returning visitor's path.
  const [fresh] = useState(() => !settings.displayName?.trim());
  const steps = fresh ? ['hello', 'you', 'look', 'tips'] as const : ['hello', 'tips'] as const;
  const [step, setStep] = useState(0);
  const [name, setName] = useState(settings.displayName ?? '');
  const [avatar, setAvatar] = useState(settings.avatar);
  const update = (patch: Partial<SettingsData>) => store.put('settings', { ...settings, ...store.settings, ...patch }, SETTINGS_ID);
  const current = steps[step]!;
  const next = () => {
    if (current === 'you' && (name.trim() !== settings.displayName || avatar !== settings.avatar)) update({ displayName: name.trim().slice(0, 40), avatar, avatarPhoto: avatar ? undefined : settings.avatarPhoto });
    if (step === steps.length - 1) finish(); else setStep(step + 1);
  };
  function finish() {
    try { localStorage.setItem(`folio.welcomed.${me.userId}`, '1'); } catch { /* private mode */ }
    onDone();
  }

  return (
    <div className="welcome" role="dialog" aria-modal="true" aria-labelledby="welcome-title">
      <div className="welcome-card glass">
        <div className="welcome-progress" aria-hidden="true">{steps.map((s, i) => <i key={s} className={i <= step ? 'on' : ''} />)}</div>
        <div key={current} className="welcome-step">
          {current === 'hello' && (
            <>
              <div className="mini-month" aria-hidden="true">
                {Array.from({ length: 28 }, (_, i) => <span key={i} className={TILES.includes(i) ? 'tile' : ''} style={{ animationDelay: `${i * 18}ms` }} />)}
              </div>
              <h1 id="welcome-title">{fresh ? 'Your days, kept.' : 'Welcome back.'}</h1>
              <p className="sub">{fresh ? 'A private diary built around your calendar. Encrypted, so only you can read it.' : 'Your diary is unlocked in this browser. Here’s where everything is.'}</p>
            </>
          )}
          {current === 'you' && (
            <>
              <h1 id="welcome-title">What should we call you?</h1>
              <label className="sr-only" htmlFor="welcome-name">Your name</label>
              <input id="welcome-name" className="field" autoFocus placeholder="Your name (optional)" maxLength={40} value={name}
                onChange={(e) => setName(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && next()} />
              <p className="caption ink2" style={{ margin: '6px 0 0' }}>A picture</p>
              <AvatarGrid current={avatar} onPick={(key) => setAvatar(key === avatar ? undefined : key)} />
            </>
          )}
          {current === 'look' && (
            <>
              <h1 id="welcome-title">Your look</h1>
              <div className="look-choices" role="radiogroup" aria-label="Appearance">
                {([['light', 'Light'], ['dark', 'Dark'], ['system', 'Match device']] as const).map(([value, label]) => (
                  <button key={value} role="radio" aria-checked={(store.settings?.appearance ?? 'system') === value} className={`look ${value}`} onClick={() => update({ appearance: value })}>
                    <span className="look-swatch" aria-hidden="true"><i /><i /><i /></span>{label}
                  </button>
                ))}
              </div>
              <p className="sub">You can change it any time in Profile.</p>
            </>
          )}
          {current === 'tips' && (
            <>
              <h1 id="welcome-title">Find your way</h1>
              <ul className="welcome-tips">
                <li><Icon name="calendar" /><span><b>Your month.</b> Days you write on get a photo or a dot. Click a day to see its pages and tasks.</span></li>
                <li><Icon name="plus" /><span><b>New entry</b> writes for the selected day. Press <kbd>N</kbd>, or drop photos on a day.</span></li>
                <li><Icon name="search" /><span><b>Search</b> with <kbd>/</kbd>. It runs in this tab only. <kbd>?</kbd> lists every shortcut.</span></li>
                <li><Icon name="mic" /><span><b>Dictation and ✦</b> stay on your iPhone, where they run privately.</span></li>
              </ul>
            </>
          )}
        </div>
        <div className="welcome-actions">
          <button className="text-btn" onClick={finish}>{step === steps.length - 1 ? '' : 'Skip'}</button>
          <button className="btn primary" onClick={next} autoFocus={current !== 'you'}>
            {current === 'hello' ? 'Get started' : step === steps.length - 1 ? 'Open my diary' : 'Continue'}
          </button>
        </div>
        <p className="welcome-mark" aria-hidden="true"><Mark />Folio</p>
      </div>
    </div>
  );
}
