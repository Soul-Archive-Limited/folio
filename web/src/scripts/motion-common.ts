/**
 * Motion shared by every marketing page: scroll reveals and the 3D tilt on cards. No library —
 * an IntersectionObserver and CSS transitions (they run off the main thread).
 */
const reduce = () => matchMedia('(prefers-reduced-motion: reduce)').matches;

export function enableReveals() {
  if (reduce()) return;
  document.documentElement.classList.add('js-motion');
  const items = document.querySelectorAll<HTMLElement>('[data-reveal]');
  const io = new IntersectionObserver((entries) => {
    for (const e of entries) {
      if (!e.isIntersecting) continue;
      e.target.classList.add('is-in');
      io.unobserve(e.target);
    }
  }, { rootMargin: '0px 0px -8% 0px' });
  items.forEach((el) => io.observe(el));
}

/** Looping illustrations ([data-play]) run only while on screen. */
export function enablePlay() {
  const io = new IntersectionObserver((entries) => {
    for (const e of entries) e.target.classList.toggle('is-playing', e.isIntersecting);
  });
  document.querySelectorAll('[data-play]').forEach((el) => io.observe(el));
}

/** Cards lean toward the pointer (fine pointers only), springing back when it leaves. */
export function enableTilt() {
  if (reduce() || !matchMedia('(hover: hover) and (pointer: fine)').matches) return;
  document.querySelectorAll<HTMLElement>('[data-tilt]').forEach((card) => {
    let frame = 0;
    card.addEventListener('pointermove', (e) => {
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(() => {
        const r = card.getBoundingClientRect();
        const x = (e.clientX - r.left) / r.width - 0.5;
        const y = (e.clientY - r.top) / r.height - 0.5;
        card.style.transition = 'transform 120ms ease-out';
        card.style.transform = `perspective(900px) rotateX(${(-y * 7).toFixed(2)}deg) rotateY(${(x * 9).toFixed(2)}deg) translateZ(6px)`;
      });
    });
    card.addEventListener('pointerleave', () => {
      cancelAnimationFrame(frame);
      card.style.transition = '';
      card.style.transform = '';
    });
  });
}
