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
