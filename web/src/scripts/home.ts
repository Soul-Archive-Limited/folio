import { animate, inView, scroll } from 'motion';
import { canRun3D, lazyScene } from './three-gate.ts';
import { startAura } from './aura.ts';
import type { SceneInput } from '../three/input.ts';

/**
 * Home page motion (Batch H). Motion's `scroll()` drives the scroll stories (it hands off to the
 * browser's ScrollTimeline where it can), `inView()` starts one-off sequences. Every effect has a
 * finished, static state without JavaScript and under Reduced Motion.
 */
const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
const clamp = (v: number, a = 0, b = 1) => Math.min(b, Math.max(a, v));
const ease = (t: number) => 1 - Math.pow(1 - t, 3);

if (!reduce) document.documentElement.classList.add('js-motion');

/* Pointer, shared by both 3D scenes and smoothed inside them. */
const sceneInputs: SceneInput[] = [];
addEventListener('pointermove', (e) => {
  const x = (e.clientX / innerWidth) * 2 - 1;
  const y = (e.clientY / innerHeight) * 2 - 1;
  for (const input of sceneInputs) { input.px = x; input.py = y; }
}, { passive: true });

/* Hero: shader aura + the 3D phone. */
const auraCanvas = document.querySelector<HTMLCanvasElement>('[data-aura]');
const hero = document.querySelector<HTMLElement>('.hero');
const stage = document.querySelector<HTMLElement>('[data-phone3d]');
const allow3D = canRun3D();
if (auraCanvas && !reduce) {
  const start = () => ('requestIdleCallback' in window ? requestIdleCallback(() => startAura(auraCanvas)) : setTimeout(() => startAura(auraCanvas), 300));
  if (document.readyState === 'complete') start(); else addEventListener('load', start, { once: true });
}
if (stage && hero && allow3D) {
  const input: SceneInput = { px: 0, py: 0, scroll: 0 };
  scroll((p: number) => { input.scroll = p; }, { target: hero, offset: ['start start', 'end start'] });
  sceneInputs.push(input);
  lazyScene(stage, 'phone', input);
}

/* Problem: four fragments gather into one day while the stage is pinned. */
const problem = document.querySelector<HTMLElement>('[data-problem]');
if (problem && !reduce && matchMedia('(min-width: 760px) and (min-height: 640px)').matches) {
  const frags = [...problem.querySelectorAll<HTMLElement>('[data-frag]')];
  const day = problem.querySelector<HTMLElement>('[data-frag-day]')!;
  const resolve = problem.querySelector<HTMLElement>('[data-resolve]')!;
  let offsets: { x: number; y: number; r: number }[] = [];
  const measure = () => {
    const box = problem.querySelector<HTMLElement>('.fragments')!.getBoundingClientRect();
    const cx = box.left + box.width / 2;
    const cy = box.top + box.height / 2;
    offsets = frags.map((f) => {
      const prev = f.style.transform;
      f.style.transform = 'none';
      const r = f.getBoundingClientRect();
      f.style.transform = prev;
      return { x: cx - (r.left + r.width / 2), y: cy - (r.top + r.height / 2), r: parseFloat(f.style.getPropertyValue('--r')) || 0 };
    });
  };
  measure();
  addEventListener('resize', measure);
  scroll((p: number) => {
    const g = ease(clamp((p - 0.12) / 0.55));
    frags.forEach((f, i) => {
      const o = offsets[i];
      f.style.transform = `translate3d(${o.x * g}px, ${o.y * g}px, 0) rotate(${o.r * (1 - g)}deg) scale(${1 - 0.72 * g})`;
      f.style.opacity = String(1 - clamp((g - 0.55) / 0.4));
    });
    const d = clamp((p - 0.5) / 0.22);
    day.style.opacity = String(d);
    day.style.transform = `scale(${0.6 + 0.4 * ease(d)})`;
    const r = clamp((p - 0.66) / 0.18);
    resolve.style.opacity = String(r);
    resolve.style.transform = `translateY(${(1 - r) * 16}px)`;
  }, { target: problem, offset: ['start start', 'end end'] });
}

/* A day with Folio: three steps, morning → afternoon → night. */
const daySection = document.querySelector<HTMLElement>('[data-day]');
if (daySection && !reduce) {
  const steps = [...daySection.querySelectorAll<HTMLElement>('[data-step]')];
  const shots = [...daySection.querySelectorAll<HTMLElement>('[data-shot]')];
  const dots = [...daySection.querySelectorAll<HTMLElement>('.day-dots i')];
  let current = -1;
  scroll((p: number) => {
    const step = p < 0.36 ? 0 : p < 0.7 ? 1 : 2;
    if (step === current) return;
    current = step;
    [steps, shots, dots].forEach((list) => list.forEach((el, i) => el.classList.toggle('is-active', i === step)));
    daySection.classList.toggle('is-noon', step === 1);
    daySection.classList.toggle('is-night', step === 2);
  }, { target: daySection, offset: ['start start', 'end end'] });
}

/* Calendar: tiles fly in from depth, photos flip in, then Sunday 25's page lifts into its entry. */
const cal = document.querySelector<HTMLElement>('[data-cal]');
if (cal && !reduce) {
  cal.classList.add('cal-armed');
  const cells = [...cal.querySelectorAll<HTMLElement>('[data-cell]')];
  const entry = cal.querySelector<HTMLElement>('[data-entry]')!;
  const lift = cal.querySelector<HTMLElement>('.cell.lift')!;
  inView(cal, () => {
    cells.forEach((cell, i) => {
      const row = Math.floor(i / 7);
      const col = i % 7;
      const delay = (row * 0.06) + (Math.abs(col - 3) * 0.035);
      const isPhoto = cell.classList.contains('photo');
      animate(cell, {
        opacity: [0, 1],
        transform: isPhoto
          ? ['translateZ(-700px) rotateX(50deg) rotateY(180deg)', 'translateZ(0) rotateX(0deg) rotateY(0deg)']
          : ['translateZ(-700px) rotateX(50deg)', 'translateZ(0) rotateX(0deg)'],
      }, { duration: isPhoto ? 1.25 : 1, delay: delay + (isPhoto ? 0.25 : 0), ease: [0.23, 1, 0.32, 1] });
    });
    // The page lifts off its day and opens into the entry (FLIP from the tile to the card).
    const from = lift.getBoundingClientRect();
    const to = entry.getBoundingClientRect();
    const dx = from.left - to.left;
    const dy = from.top - to.top;
    const sx = from.width / to.width;
    const sy = from.height / to.height;
    animate(entry, {
      opacity: [0, 1, 1],
      transform: [`translate(${dx}px, ${dy}px) scale(${sx}, ${sy})`, `translate(${dx}px, ${dy - 40}px) scale(${sx * 1.4}, ${sy * 1.4})`, 'translate(0px, 0px) scale(1, 1)'],
    }, { duration: 1.1, delay: 1.5, ease: [0.77, 0, 0.175, 1], times: [0, 0.2, 1] });
    animate(lift, { transform: ['translateZ(0)', 'translateZ(60px)', 'translateZ(0)'] }, { duration: 0.6, delay: 1.45 });
  }, { amount: 0.35 });
}

/* Privacy: the 3D lock closes with scroll, and the page's words scramble into ciphertext. */
const privacy = document.querySelector<HTMLElement>('[data-privacy]');
if (privacy) {
  const lockStage = privacy.querySelector<HTMLElement>('[data-lock3d]');
  const text = privacy.querySelector<HTMLElement>('[data-cipher]')!;
  const label = privacy.querySelector<HTMLElement>('[data-cipher-label]')!;
  const plain = text.dataset.plain ?? '';
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  // A fixed pseudo-random stand-in for AES-GCM output (the real thing is never shown here).
  const cipher = Array.from(plain, (_, i) => alphabet[(i * 37 + 11 + ((i * i) % 13)) % 64]).join('');
  const input: SceneInput = { px: 0, py: 0, scroll: reduce ? 1 : 0 };
  const render = (p: number) => {
    const n = Math.round(plain.length * clamp((p - 0.25) / 0.5));
    text.textContent = cipher.slice(0, n) + plain.slice(n);
    label.textContent = n >= plain.length ? 'What our server stores' : 'What you write';
  };
  if (reduce) render(1);
  else {
    scroll((p: number) => {
      input.scroll = clamp((p - 0.2) / 0.45);
      render(p);
    }, { target: privacy, offset: ['start end', 'end start'] });
  }
  if (lockStage && allow3D) {
    sceneInputs.push(input);
    lazyScene(lockStage, 'lock', input);
  }
}
