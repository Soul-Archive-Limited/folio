import type { SceneInput } from '../three/input.ts';

/**
 * Decides whether this device gets the 3D scenes, and loads them lazily (Batch H performance
 * rules): never before the page has loaded and gone idle, only when the stage is near the
 * viewport, never with Reduced Motion, Save-Data, little memory, few cores or a software
 * renderer. Everyone else keeps the static poster, which is designed to stand on its own.
 */
export function canRun3D(): boolean {
  if (matchMedia('(prefers-reduced-motion: reduce)').matches) return false;
  const nav = navigator as Navigator & { deviceMemory?: number; connection?: { saveData?: boolean } };
  if (nav.connection?.saveData) return false;
  if ((nav.deviceMemory ?? 8) < 4) return false;
  if ((navigator.hardwareConcurrency ?? 8) < 4) return false;
  try {
    const gl = document.createElement('canvas').getContext('webgl2');
    if (!gl) return false;
    const info = gl.getExtension('WEBGL_debug_renderer_info');
    const renderer = info ? String(gl.getParameter(info.UNMASKED_RENDERER_WEBGL)) : '';
    gl.getExtension('WEBGL_lose_context')?.loseContext();
    if (/swiftshader|llvmpipe|software/i.test(renderer)) return false;
  } catch {
    return false;
  }
  return true;
}

let pageReady: Promise<void> | null = null;
/**
 * Resolves after `load` and an idle moment, so 3D never competes with the first paint. On touch
 * devices it also waits for the visitor's first scroll or touch: phones are where parsing and
 * compiling the scene costs the most, and nobody who leaves straight away pays for it.
 */
function afterLoadAndIdle(): Promise<void> {
  pageReady ??= new Promise((resolve) => {
    const idle = () => ('requestIdleCallback' in window ? requestIdleCallback(() => resolve(), { timeout: 2500 }) : setTimeout(resolve, 600));
    const loaded = () => {
      if (!matchMedia('(pointer: coarse)').matches) return idle();
      const events = ['scroll', 'touchstart', 'pointerdown', 'keydown'] as const;
      const go = () => { events.forEach((e) => removeEventListener(e, go)); idle(); };
      events.forEach((e) => addEventListener(e, go, { passive: true, once: true }));
    };
    if (document.readyState === 'complete') loaded();
    else addEventListener('load', loaded, { once: true });
  });
  return pageReady;
}

/** Mounts a scene into `stage` once it nears the viewport. `stage` gets `is-3d` when the first frame is on screen. */
export function lazyScene(stage: HTMLElement, kind: 'phone' | 'lock', input: SceneInput) {
  const io = new IntersectionObserver(async ([entry]) => {
    if (!entry.isIntersecting) return;
    io.disconnect();
    await afterLoadAndIdle();
    try {
      const { mountScene } = await import('../three/mount.tsx');
      mountScene(stage, kind, input, () => stage.classList.add('is-3d'));
    } catch {
      // The poster stays; nothing else depends on the 3D scene.
    }
  }, { rootMargin: '200px' });
  io.observe(stage);
}
