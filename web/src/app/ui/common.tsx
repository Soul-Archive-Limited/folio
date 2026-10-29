import { createContext, type ReactNode, useContext, useEffect, useRef, useState } from 'react';
import { categoryColor } from '../lib/payloads.ts';
import { photoURL, type Rendition } from '../lib/photos.ts';
import { useDiary, type Toast } from './context.tsx';
import { Icon } from './Icons.tsx';

const SheetClose = createContext<() => void>(() => {});
/** Closes the enclosing sheet with its animation. */
export const useCloseSheet = () => useContext(SheetClose);

/**
 * A glass sheet: from the right on wider screens (the calendar stays visible), a bottom
 * drawer on phones (SPEC §11.3). Escape or the scrim close it; focus moves in and back.
 */
export function Sheet({ label, onClose, children, wide, tall, scrim, bar, canClose }: {
  label: string; onClose: () => void; children: ReactNode; wide?: boolean; tall?: boolean; scrim?: boolean; bar?: ReactNode;
  /** Return false to stay open (e.g. to ask about unsaved changes first). */
  canClose?: () => boolean;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const [closing, setClosing] = useState(false);
  const [expanded, setExpanded] = useState(!!tall);
  const close = () => {
    if (closing || (canClose && !canClose())) return;
    setClosing(true);
    // The exit is a slide, or a 0.2 s fade under reduced motion (app.css): unmount after it.
    setTimeout(onClose, 220);
  };
  useEffect(() => {
    const previous = document.activeElement as HTMLElement | null;
    ref.current?.querySelector<HTMLElement>('[autofocus], input, textarea, [contenteditable], button')?.focus({ preventScroll: true });
    const onKey = (event: KeyboardEvent) => event.key === 'Escape' && !event.defaultPrevented && close();
    window.addEventListener('keydown', onKey);
    return () => {
      window.removeEventListener('keydown', onKey);
      previous?.focus?.({ preventScroll: true });
    };
  }, []);
  return (
    <div className="sheet-host">
      {scrim && <div className="scrim" onClick={close} />}
      <div ref={ref} role="dialog" aria-modal={scrim ? true : undefined} aria-label={label}
        className={`sheet glass${wide ? ' wide' : ''}${expanded ? ' tall' : ''}${closing ? ' closing' : ''}`}>
        <button className="grabber" aria-label={expanded ? 'Make smaller' : 'Make taller'} onClick={() => setExpanded(!expanded)} />
        {bar && <div className="sheet-bar">{bar}</div>}
        <SheetClose.Provider value={close}>{children}</SheetClose.Provider>
      </div>
    </div>
  );
}


export function Modal({ title, message, children, onClose }: { title: string; message?: ReactNode; children: ReactNode; onClose: () => void }) {
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        event.preventDefault();
        onClose();
      }
    };
    window.addEventListener('keydown', onKey, true);
    return () => window.removeEventListener('keydown', onKey, true);
  }, [onClose]);
  return (
    <div className="modal-host" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className="modal glass" role="alertdialog" aria-modal="true" aria-label={title}>
        <h2 className="headline">{title}</h2>
        {message && <div className="callout ink2">{message}</div>}
        <div className="actions">{children}</div>
      </div>
    </div>
  );
}

export function Toasts({ toasts, dismiss }: { toasts: Toast[]; dismiss: (id: number) => void }) {
  return (
    <div className="toasts" role="status" aria-live="polite">
      {toasts.map((t) => (
        <div key={t.id} className="toast glass">
          <span className="grow">{t.text}</span>
          {t.action && (
            <button className="link" onClick={() => { t.action!.run(); dismiss(t.id); }}>{t.action.label}</button>
          )}
        </div>
      ))}
    </div>
  );
}

/** A decrypted photo; tries the next smaller rendition if a browser can't show one (HEIC). */
export function PhotoImg({ id, rendition, alt = '', className, fallback = true }: { id: string; rendition: Rendition; alt?: string; className?: string; fallback?: boolean }) {
  const { key, me } = useDiary();
  const order: Rendition[] = rendition === 'full' ? ['full', 'display', 'thumb'] : rendition === 'display' ? ['display', 'thumb'] : ['thumb'];
  const [step, setStep] = useState(0);
  const [url, setUrl] = useState<string | null>(null);
  useEffect(() => {
    let live = true;
    setUrl(null);
    void photoURL(key, me.userId, id, order[step]!).then((u) => {
      if (!live) return;
      if (u) setUrl(u);
      else if (fallback && step < order.length - 1) setStep(step + 1);
    });
    return () => { live = false; };
  }, [id, step]);
  if (!url) return <span className="ph" aria-hidden="true" />;
  return <img className={className} src={url} alt={alt} decoding="async" onError={() => fallback && step < order.length - 1 && setStep(step + 1)} />;
}

export function CategoryChip({ id }: { id?: string }) {
  const { store } = useDiary();
  const category = store.category(id);
  if (!category) return null;
  return (
    <span className="chip" style={{ ['--c' as string]: categoryColor(category.data.colorKey), minHeight: 24, fontSize: 12 }}>
      <i className="dot" />{category.data.name}
    </span>
  );
}

/** Category filter / picker chips (SPEC §6.2, §6.6, §6.7). */
export function CategoryChips({ selected, onSelect, allLabel = 'All', onCreate }: {
  selected: string | null; onSelect: (id: string | null) => void; allLabel?: string; onCreate?: () => void;
}) {
  const { store } = useDiary();
  return (
    <div className="chips" role="group" aria-label="Categories">
      <button className="chip" aria-pressed={selected === null} onClick={() => onSelect(null)}>{allLabel}</button>
      {store.categories().map((c) => (
        <button key={c.id} className="chip" aria-pressed={!!selected && selected.toLowerCase() === c.id.toLowerCase()}
          style={{ ['--c' as string]: categoryColor(c.data.colorKey) }} onClick={() => onSelect(c.id)}>
          <i className="dot" />{c.data.name}
        </button>
      ))}
      {onCreate && <button className="chip" onClick={onCreate} aria-label="New category"><Icon name="plus" small /></button>}
    </div>
  );
}

export function Empty({ icon, text, children }: { icon: string; text: string; children?: ReactNode }) {
  return (
    <div className="empty">
      <div className="glyph glass"><Icon name={icon} /></div>
      <p className="callout ink2">{text}</p>
      {children && <div className="row">{children}</div>}
    </div>
  );
}

/** "Available in the iPhone app" for dictation and ✦ (SPEC §11.3). */
export function IPhoneOnly({ onDone }: { onDone: () => void }) {
  useEffect(() => {
    const timer = setTimeout(onDone, 2400);
    return () => clearTimeout(timer);
  }, []);
  return <div className="iphone-only glass" role="status">Available in the iPhone app</div>;
}
