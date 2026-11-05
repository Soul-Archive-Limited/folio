/** Mood (Batch J): five steps, Folio's own ring that fills from the bottom — never a face. */
export const MOODS = [
  { value: 1, title: 'Heavy', color: 'var(--cat-indigo)', opacity: 1 },
  { value: 2, title: 'Low', color: 'var(--cat-indigo)', opacity: 0.5 },
  { value: 3, title: 'Steady', color: 'var(--cat-sand)', opacity: 0.75 },
  { value: 4, title: 'Good', color: 'var(--ember)', opacity: 0.55 },
  { value: 5, title: 'Bright', color: 'var(--ember)', opacity: 1 },
] as const;

/** A synced mood, or undefined when missing or off the scale (a crafted record). */
export const moodOf = (value: unknown) => MOODS.find((m) => m.value === value);

export function MoodGlyph({ mood, size = 18 }: { mood?: number; size?: number }) {
  const m = moodOf(mood);
  const r = size / 2;
  const ring = Math.max(size / 11, 1.5);
  const fillHeight = m ? size * (m.value / 5) : 0;
  const clip = `mg-${size}-${m?.value ?? 0}`;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} aria-hidden="true" style={{ flex: 'none' }}>
      <circle cx={r} cy={r} r={r - ring / 2} fill="none" stroke={m ? m.color : 'var(--ink-secondary)'} strokeOpacity={m ? m.opacity : 0.7} strokeWidth={ring} />
      {m && (
        <>
          <clipPath id={clip}><rect x="0" y={size - fillHeight} width={size} height={fillHeight} /></clipPath>
          <circle cx={r} cy={r} r={r - ring - 1} fill={m.color} fillOpacity={m.opacity} clipPath={`url(#${clip})`} />
        </>
      )}
    </svg>
  );
}

export function MoodPicker({ value, onChange }: { value?: number; onChange: (mood: number | undefined) => void }) {
  return (
    <div className="mood-picker" role="radiogroup" aria-label="How did it feel?">
      {MOODS.map((m) => (
        <button key={m.value} role="radio" aria-checked={value === m.value} title={m.title}
          onClick={() => onChange(value === m.value ? undefined : m.value)}>
          <MoodGlyph mood={m.value} size={22} /><span>{m.title}</span>
        </button>
      ))}
    </div>
  );
}
