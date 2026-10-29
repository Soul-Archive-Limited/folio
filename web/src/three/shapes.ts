import * as THREE from 'three';
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js';

/** A rounded rectangle centred on the origin; quadratic corners read softer than circular arcs. */
export function roundedRect(w: number, h: number, r: number): THREE.Shape {
  const s = new THREE.Shape();
  const x = -w / 2;
  const y = -h / 2;
  s.moveTo(x + r, y);
  s.lineTo(x + w - r, y);
  s.quadraticCurveTo(x + w, y, x + w, y + r);
  s.lineTo(x + w, y + h - r);
  s.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  s.lineTo(x + r, y + h);
  s.quadraticCurveTo(x, y + h, x, y + h - r);
  s.lineTo(x, y + r);
  s.quadraticCurveTo(x, y, x + r, y);
  return s;
}

/** A flat shape whose UVs run 0–1 across its bounds, so a screenshot fills it exactly. */
export function flatShape(w: number, h: number, r: number): THREE.ShapeGeometry {
  const geometry = new THREE.ShapeGeometry(roundedRect(w, h, r), 24);
  const pos = geometry.attributes.position;
  const uv = geometry.attributes.uv;
  for (let i = 0; i < pos.count; i += 1) uv.setXY(i, pos.getX(i) / w + 0.5, pos.getY(i) / h + 0.5);
  uv.needsUpdate = true;
  return geometry;
}

/** A slab with rounded corners and bevelled edges, centred in depth. */
export function slab(w: number, h: number, r: number, depth: number, bevel: number): THREE.ExtrudeGeometry {
  const geometry = new THREE.ExtrudeGeometry(roundedRect(w - 2 * bevel, h - 2 * bevel, Math.max(r - bevel, 0.001)), {
    depth: depth - 2 * bevel, bevelEnabled: true, bevelThickness: bevel, bevelSize: bevel, bevelSegments: 6, curveSegments: 24,
  });
  geometry.translate(0, 0, -(depth - 2 * bevel) / 2);
  return geometry;
}

/** A soft studio environment made in code (no HDR download), so metal and glass catch light. */
export function studioEnvironment(renderer: THREE.WebGLRenderer): THREE.Texture {
  const pmrem = new THREE.PMREMGenerator(renderer);
  const texture = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
  pmrem.dispose();
  return texture;
}

/** A radial shadow texture for the floor under a floating object. */
export function shadowTexture(): THREE.CanvasTexture {
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = 128;
  const ctx = canvas.getContext('2d')!;
  const g = ctx.createRadialGradient(64, 64, 0, 64, 64, 64);
  g.addColorStop(0, 'rgba(40,20,10,0.55)');
  g.addColorStop(0.5, 'rgba(40,20,10,0.18)');
  g.addColorStop(1, 'rgba(40,20,10,0)');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, 128, 128);
  return new THREE.CanvasTexture(canvas);
}

/** Folio's mark (a page with an ember dot) for the back of the phone. */
export function markTexture(ink: string, paper: string, ember: string): THREE.CanvasTexture {
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = 256;
  const ctx = canvas.getContext('2d')!;
  ctx.fillStyle = ink;
  ctx.beginPath();
  ctx.roundRect(46, 22, 164, 212, 32);
  ctx.fill();
  ctx.fillStyle = paper;
  ctx.globalAlpha = 0.35;
  for (const [y, w] of [[104, 106], [132, 120], [160, 90]] as const) {
    ctx.beginPath();
    ctx.roundRect(74, y, w, 11, 5.5);
    ctx.fill();
  }
  ctx.globalAlpha = 1;
  ctx.fillStyle = ember;
  ctx.beginPath();
  ctx.arc(196, 42, 28, 0, Math.PI * 2);
  ctx.fill();
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}

export const damp = THREE.MathUtils.damp;
