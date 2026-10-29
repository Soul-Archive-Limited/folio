import { useEffect, useMemo, useRef } from 'react';
import { useFrame, useLoader, useThree } from '@react-three/fiber';
import * as THREE from 'three';
import { damp, flatShape, markTexture, shadowTexture, slab, studioEnvironment } from './shapes.ts';
import type { SceneInput } from './input.ts';

/**
 * Our own simple phone (no real device model): a rounded slab, a black glass front and a real
 * Folio screenshot as the screen. It floats, leans toward the cursor and turns as the hero
 * scrolls away. Units: the phone is 1 wide.
 */
const W = 1;
const SCREEN_W = 0.93;
const SCREEN_H = SCREEN_W * (2622 / 1206);
const H = SCREEN_H + 0.075;
const D = 0.1;
const R = 0.165;

/** The resting pose; the CSS poster uses the same lean. */
export const PHONE_POSE = { rx: 0.09, ry: -0.3, rz: 0.035 };

export function Phone({ dark, screen, input }: { dark: boolean; screen: string; input: SceneInput }) {
  const group = useRef<THREE.Group>(null);
  const { gl, scene } = useThree();
  const texture = useLoader(THREE.TextureLoader, screen);

  useEffect(() => {
    const env = studioEnvironment(gl);
    scene.environment = env;
    return () => env.dispose();
  }, [gl, scene]);

  useMemo(() => {
    texture.colorSpace = THREE.SRGBColorSpace;
    texture.anisotropy = gl.capabilities.getMaxAnisotropy();
  }, [texture, gl]);

  const parts = useMemo(() => ({
    body: slab(W, H, R, D, 0.022),
    glass: flatShape(W - 0.024, H - 0.024, R - 0.012),
    screen: flatShape(SCREEN_W, SCREEN_H, 0.13),
    button: slab(0.05, 0.2, 0.02, 0.02, 0.008),
    shadow: shadowTexture(),
  }), []);

  const mark = useMemo(() => (dark ? markTexture('#f4f4f5', '#16161a', '#ff7a45') : markTexture('#16161a', '#f5f3ef', '#f0602a')), [dark]);
  const frameColor = dark ? '#3b3b41' : '#d8d1c6';

  useFrame((state, delta) => {
    const g = group.current;
    if (!g) return;
    const t = state.clock.elapsedTime;
    const { px, py, scroll } = input;
    const dt = Math.min(delta, 1 / 20);
    g.rotation.y = damp(g.rotation.y, PHONE_POSE.ry + px * 0.32 + scroll * 1.15, 3.5, dt);
    g.rotation.x = damp(g.rotation.x, PHONE_POSE.rx + py * 0.16 + scroll * 0.22, 3.5, dt);
    g.rotation.z = PHONE_POSE.rz + Math.sin(t * 0.55) * 0.012;
    g.position.y = damp(g.position.y, Math.sin(t * 0.8) * 0.045 + scroll * 0.55, 6, dt);
  });

  return (
    <>
      <group ref={group} rotation={[PHONE_POSE.rx, PHONE_POSE.ry, PHONE_POSE.rz]}>
        <mesh geometry={parts.body}>
          <meshPhysicalMaterial color={frameColor} metalness={0.85} roughness={0.32} clearcoat={0.4} clearcoatRoughness={0.3} />
        </mesh>
        <mesh geometry={parts.glass} position={[0, 0, D / 2 + 0.0006]}>
          <meshPhysicalMaterial color="#09090b" metalness={0} roughness={0.08} clearcoat={1} clearcoatRoughness={0.05} />
        </mesh>
        <mesh geometry={parts.screen} position={[0, 0, D / 2 + 0.0012]}>
          <meshBasicMaterial map={texture} toneMapped={false} />
        </mesh>
        <mesh position={[0, 0.25, -D / 2 - 0.0008]} rotation={[0, Math.PI, 0]}>
          <planeGeometry args={[0.26, 0.26]} />
          <meshBasicMaterial map={mark} transparent toneMapped={false} />
        </mesh>
        <mesh geometry={parts.button} position={[W / 2 + 0.004, 0.42, 0]} rotation={[0, Math.PI / 2, 0]}>
          <meshStandardMaterial color={frameColor} metalness={0.9} roughness={0.3} />
        </mesh>
        <mesh geometry={parts.button} position={[-W / 2 - 0.004, 0.52, 0]} rotation={[0, Math.PI / 2, 0]} scale={[1, 0.6, 1]}>
          <meshStandardMaterial color={frameColor} metalness={0.9} roughness={0.3} />
        </mesh>
        <mesh geometry={parts.button} position={[-W / 2 - 0.004, 0.3, 0]} rotation={[0, Math.PI / 2, 0]} scale={[1, 0.6, 1]}>
          <meshStandardMaterial color={frameColor} metalness={0.9} roughness={0.3} />
        </mesh>
      </group>
      <mesh position={[0, -H / 2 - 0.2, 0]} rotation={[-Math.PI / 2, 0, 0]} scale={[1.7, 0.7, 1]}>
        <planeGeometry args={[1, 1]} />
        <meshBasicMaterial map={parts.shadow} transparent depthWrite={false} opacity={dark ? 0.9 : 0.7} />
      </mesh>
    </>
  );
}
