import { useEffect, useMemo, useRef } from 'react';
import { useFrame, useThree } from '@react-three/fiber';
import * as THREE from 'three';
import { damp, flatShape, roundedRect, shadowTexture, slab, studioEnvironment } from './shapes.ts';
import type { SceneInput } from './input.ts';

/**
 * The privacy section's lock: an ember body and a steel shackle that swings shut as you scroll
 * (`input.scroll` 0 = open, 1 = closed). Built from primitives; no model file.
 */
const BW = 1.5;
const BH = 1.2;
const LEG = 0.43;

function shackleCurve() {
  const points: THREE.Vector3[] = [];
  for (let y = 0.1; y <= 0.9; y += 0.1) points.push(new THREE.Vector3(-LEG, y, 0));
  for (let i = 1; i < 24; i += 1) {
    const a = Math.PI - (i / 24) * Math.PI;
    points.push(new THREE.Vector3(Math.cos(a) * LEG, 0.9 + Math.sin(a) * LEG, 0));
  }
  for (let y = 0.9; y >= 0.1; y -= 0.1) points.push(new THREE.Vector3(LEG, y, 0));
  return new THREE.CatmullRomCurve3(points, false, 'centripetal');
}

function keyholeGeometry() {
  const s = new THREE.Shape();
  s.absarc(0, 0.06, 0.1, 0, Math.PI * 2, false);
  const stem = roundedRect(0.08, 0.26, 0.03);
  const stemGeometry = new THREE.ShapeGeometry(stem, 8);
  stemGeometry.translate(0, -0.14, 0);
  return [new THREE.ShapeGeometry(s, 32), stemGeometry];
}

export function Lock({ dark, input }: { dark: boolean; input: SceneInput }) {
  const group = useRef<THREE.Group>(null);
  const shackle = useRef<THREE.Group>(null);
  const { gl, scene } = useThree();

  useEffect(() => {
    const env = studioEnvironment(gl);
    scene.environment = env;
    return () => env.dispose();
  }, [gl, scene]);

  const parts = useMemo(() => ({
    body: slab(BW, BH, 0.22, 0.56, 0.07),
    tube: new THREE.TubeGeometry(shackleCurve(), 96, 0.095, 20, false),
    keyhole: keyholeGeometry(),
    plate: flatShape(BW - 0.36, BH - 0.36, 0.14),
    shadow: shadowTexture(),
  }), []);

  const progress = useRef(0);
  useFrame((state, delta) => {
    const dt = Math.min(delta, 1 / 20);
    const t = state.clock.elapsedTime;
    progress.current = damp(progress.current, input.scroll, 7, dt);
    const p = progress.current;
    const open = 1 - p;
    if (shackle.current) {
      shackle.current.position.y = BH / 2 - 0.42 + open * 0.34;
      shackle.current.rotation.y = -open * 1.25;
    }
    const g = group.current;
    if (g) {
      g.rotation.y = damp(g.rotation.y, 0.55 * open - 0.18 + input.px * 0.3, 3.5, dt);
      g.rotation.x = damp(g.rotation.x, 0.12 + input.py * 0.12, 3.5, dt);
      g.position.y = Math.sin(t * 0.8) * 0.035 - 0.15;
    }
  });

  const ember = dark ? '#f2622c' : '#e4521d';
  return (
    <>
      <group ref={group}>
        <mesh geometry={parts.body}>
          <meshPhysicalMaterial color={ember} roughness={0.42} metalness={0.05} clearcoat={0.6} clearcoatRoughness={0.3} envMapIntensity={0.55} />
        </mesh>
        <mesh geometry={parts.plate} position={[0, 0, 0.2801]}>
          <meshPhysicalMaterial color={ember} roughness={0.55} metalness={0} clearcoat={0.2} envMapIntensity={0.5} />
        </mesh>
        {parts.keyhole.map((geometry, i) => (
          <mesh key={i} geometry={geometry} position={[0, 0, 0.2806]}>
            <meshBasicMaterial color="#1a0d08" />
          </mesh>
        ))}
        {/* The pivot sits on the left leg, so the shackle swings open the way a real one does. */}
        <group ref={shackle} position={[-LEG, BH / 2 - 0.08, 0]}>
          <mesh geometry={parts.tube} position={[LEG, 0, 0]}>
            <meshPhysicalMaterial color={dark ? '#c9c7c3' : '#dcd9d4'} metalness={1} roughness={0.22} clearcoat={0.3} />
          </mesh>
        </group>
      </group>
      <mesh position={[0, -BH / 2 - 0.42, 0]} rotation={[-Math.PI / 2, 0, 0]} scale={[2.2, 0.9, 1]}>
        <planeGeometry args={[1, 1]} />
        <meshBasicMaterial map={parts.shadow} transparent depthWrite={false} opacity={dark ? 0.9 : 0.6} />
      </mesh>
    </>
  );
}
