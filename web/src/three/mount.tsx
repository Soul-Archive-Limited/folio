import { Suspense, useEffect } from 'react';
import { createRoot } from 'react-dom/client';
import { Canvas, useThree } from '@react-three/fiber';
import * as THREE from 'three';
import { Phone } from './Phone.tsx';
import { Lock } from './Lock.tsx';
import type { SceneInput } from './input.ts';

type Kind = 'phone' | 'lock';

/** Calls `onReady` after the first frame with everything loaded, so the poster can fade out. */
function Ready({ onReady }: { onReady: () => void }) {
  const { invalidate } = useThree();
  useEffect(() => {
    let raf = requestAnimationFrame(() => { raf = requestAnimationFrame(onReady); });
    invalidate();
    return () => cancelAnimationFrame(raf);
  }, []);
  return null;
}

/** Renders only while the stage is on screen; off screen the loop stops entirely. */
function Visibility({ el }: { el: HTMLElement }) {
  const { setFrameloop } = useThree();
  useEffect(() => {
    const io = new IntersectionObserver(([e]) => setFrameloop(e.isIntersecting ? 'always' : 'never'), { rootMargin: '80px' });
    io.observe(el);
    return () => io.disconnect();
  }, [el, setFrameloop]);
  return null;
}

/**
 * Mounts one 3D scene into `el`. Returns a cleanup. The whole three.js + React Three Fiber
 * stack lives in this lazily imported chunk; the page never waits for it.
 */
export function mountScene(el: HTMLElement, kind: Kind, input: SceneInput, onReady: () => void) {
  const host = document.createElement('div');
  host.style.cssText = 'position:absolute;inset:0';
  host.setAttribute('aria-hidden', 'true');
  el.append(host);
  const root = createRoot(host);
  const scheme = matchMedia('(prefers-color-scheme: dark)');
  const small = matchMedia('(max-width: 900px)').matches;

  const render = () => {
    const dark = scheme.matches;
    root.render(
      <Canvas
        dpr={[1, small ? 1.75 : 2]}
        gl={{ alpha: true, antialias: true, powerPreference: 'low-power' }}
        camera={{ fov: kind === 'phone' ? 22.5 : 30, position: kind === 'phone' ? [0, 0.35, 6.6] : [0, 0.45, 6.2] }}
        onCreated={({ camera, gl }) => { camera.lookAt(0, 0, 0); gl.toneMapping = THREE.ACESFilmicToneMapping; gl.toneMappingExposure = 1.05; }}
        style={{ pointerEvents: 'none' }}
      >
        <ambientLight intensity={0.35} />
        <directionalLight position={[3, 4, 5]} intensity={1.4} />
        <directionalLight position={[-4, 1, -3]} intensity={0.6} color={dark ? '#7a8cff' : '#ffd2b8'} />
        <Suspense fallback={null}>
          {kind === 'phone'
            ? <Phone dark={dark} input={input} screen={`/img/app/calendar-today-${dark ? 'dark' : 'light'}.webp`} />
            : <Lock dark={dark} input={input} />}
          <Ready onReady={onReady} />
        </Suspense>
        <Visibility el={el} />
      </Canvas>,
    );
  };
  render();
  scheme.addEventListener('change', render);
  return () => { scheme.removeEventListener('change', render); root.unmount(); host.remove(); };
}
