/**
 * The hero's aura as a tiny fragment shader (no library): three soft colour fields drifting on
 * slow 18–30 s paths, as in the app (SPEC §3.5). Rendered at a fraction of the size — it is a
 * blur anyway — at 30 fps, only while on screen and the tab is visible. Reduced Motion draws one
 * still frame. The CSS blobs underneath stay as the poster and the fallback.
 */
const vertex = `attribute vec2 p; void main() { gl_Position = vec4(p, 0.0, 1.0); }`;
const fragment = `
precision mediump float;
uniform vec2 res; uniform float t; uniform vec3 c1; uniform vec3 c2; uniform vec3 c3; uniform float strength;
float field(vec2 uv, vec2 c, float r) { float d = length((uv - c) * vec2(res.x / res.y, 1.0)); return exp(-d * d / (r * r)); }
void main() {
  vec2 uv = gl_FragCoord.xy / res;
  vec2 a = vec2(0.72 + 0.10 * sin(t / 4.1), 0.66 + 0.08 * cos(t / 3.3));
  vec2 b = vec2(0.92 + 0.07 * cos(t / 4.8), 0.38 + 0.10 * sin(t / 3.9));
  vec2 c = vec2(0.10 + 0.09 * sin(t / 3.0), 0.26 + 0.07 * cos(t / 4.6));
  float fa = field(uv, a, 0.36), fb = field(uv, b, 0.30), fc = field(uv, c, 0.34) * 0.75;
  vec3 col = c1 * fa + c2 * fb + c3 * fc;
  float alpha = clamp((fa + fb + fc) * strength, 0.0, 1.0);
  gl_FragColor = vec4(col / max(fa + fb + fc, 0.001) * alpha, alpha);
}`;

function rgb(value: string): [number, number, number] {
  const hex = value.trim().replace('#', '');
  const n = parseInt(hex.length === 3 ? hex.replace(/./g, (c) => c + c) : hex, 16);
  return [((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255];
}

export function startAura(canvas: HTMLCanvasElement) {
  const gl = canvas.getContext('webgl', { premultipliedAlpha: true, antialias: false, alpha: true });
  if (!gl) return;
  const compile = (type: number, src: string) => {
    const s = gl.createShader(type)!;
    gl.shaderSource(s, src);
    gl.compileShader(s);
    return s;
  };
  const program = gl.createProgram()!;
  gl.attachShader(program, compile(gl.VERTEX_SHADER, vertex));
  gl.attachShader(program, compile(gl.FRAGMENT_SHADER, fragment));
  gl.linkProgram(program);
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) return;
  gl.useProgram(program);
  gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
  const loc = gl.getAttribLocation(program, 'p');
  gl.enableVertexAttribArray(loc);
  gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);
  const u = (name: string) => gl.getUniformLocation(program, name);

  const scheme = matchMedia('(prefers-color-scheme: dark)');
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const colours = () => {
    const css = getComputedStyle(document.documentElement);
    gl.uniform3fv(u('c1'), rgb(css.getPropertyValue('--aura1')));
    gl.uniform3fv(u('c2'), rgb(css.getPropertyValue('--aura2')));
    gl.uniform3fv(u('c3'), rgb(css.getPropertyValue('--aura3')));
    gl.uniform1f(u('strength'), scheme.matches ? 0.2 : 0.5);
  };
  const size = () => {
    const scale = 0.16;
    canvas.width = Math.max(2, Math.round(canvas.clientWidth * scale));
    canvas.height = Math.max(2, Math.round(canvas.clientHeight * scale));
    gl.viewport(0, 0, canvas.width, canvas.height);
    gl.uniform2f(u('res'), canvas.width, canvas.height);
  };
  colours();
  size();
  scheme.addEventListener('change', () => { colours(); draw(performance.now()); });
  new ResizeObserver(() => { size(); draw(performance.now()); }).observe(canvas);

  const start = performance.now() - 20000;
  const draw = (now: number) => {
    gl.uniform1f(u('t'), (now - start) / 1000);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
  };
  draw(performance.now());
  canvas.classList.add('is-on');
  if (reduce) return;

  let visible = true;
  let last = 0;
  let raf = 0;
  const loop = (now: number) => {
    raf = requestAnimationFrame(loop);
    if (now - last < 33) return;
    last = now;
    draw(now);
  };
  const update = () => {
    cancelAnimationFrame(raf);
    if (visible && !document.hidden) raf = requestAnimationFrame(loop);
  };
  new IntersectionObserver(([e]) => { visible = e.isIntersecting; update(); }).observe(canvas);
  document.addEventListener('visibilitychange', update);
}
