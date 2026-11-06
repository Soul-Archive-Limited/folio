// The real-time sync test matrix (Batch L, SPEC §10.5): two browsers and one iPhone Simulator
// on one account. Each row makes one change on one device and times how long each other device
// takes to have it. The iPhone runs a DEBUG build with `-FolioSyncProbe YES` (SyncProbe.swift):
// commands go in through a file in its container and its log says when it pushed or applied.
//
//   node scripts/sync-matrix.mjs --sim <udid> --web http://localhost:8788 --api http://127.0.0.1:8787/api/ \
//     --profiles <dirA>,<dirB> --out docs/reports/batch-l-sync.json [--playwright <dir with playwright-core>]
//
// Both browser profiles must already be signed in and trusted (unlocked) on the same account as
// the Simulator. No secrets are read or written here.
import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, renameSync, writeFileSync, mkdirSync } from 'node:fs';
import { createRequire } from 'node:module';
import { join, dirname } from 'node:path';

const args = Object.fromEntries(process.argv.slice(2).reduce((list, value, i, all) => (value.startsWith('--') ? [...list, [value.slice(2), all[i + 1]]] : list), []));
const require = createRequire(join(args.playwright ?? process.cwd(), 'noop.js'));
const { chromium } = require('playwright-core');
const SIM = args.sim, WEB = args.web, API = args.api;
const [profileA, profileB] = args.profiles.split(',');
const BRAVE = '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser';
const RUN = Date.now().toString(36).slice(-4).toUpperCase();
const T = (name) => `SYNC-${RUN}-${name}`;
const results = [];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// MARK: iPhone
const simctl = (...a) => execFileSync('xcrun', ['simctl', ...a]).toString().trim();
function phoneLaunch() {
  try { simctl('terminate', SIM, 'com.devilsense.folio'); } catch { /* not running */ }
  simctl('launch', SIM, 'com.devilsense.folio', '-FolioAPIBase', API, '-FolioSyncProbe', 'YES', '-hasOnboarded', 'YES', '-FolioSkipGreeting', 'YES',
    '-com.apple.TipKit.HideAllTips', '1', '-FolioTab', 'journal');
}
const container = () => simctl('get_app_container', SIM, 'com.devilsense.folio', 'data');
const probeLog = () => join(container(), 'Documents', 'sync-probe.log');
function phone(line) {
  const docs = join(container(), 'Documents');
  const tmp = join(docs, `probe-in-${Date.now()}.tmp`);
  writeFileSync(tmp, `${line}\n`);
  renameSync(tmp, join(docs, 'probe-in.txt'));
  return Date.now();
}
/** Waits for a probe log line after `since` matching `pattern`; returns its timestamp. */
async function phoneSees(pattern, since, timeout = 60000) {
  const end = Date.now() + timeout;
  while (Date.now() < end) {
    if (existsSync(probeLog())) {
      for (const line of readFileSync(probeLog(), 'utf8').split('\n')) {
        const [ms, ...rest] = line.split(' ');
        if (Number(ms) >= since && pattern.test(rest.join(' '))) return Number(ms);
      }
    }
    await sleep(40);
  }
  return null;
}

// MARK: Browsers
async function openBrowser(profile, label) {
  const ctx = await chromium.launchPersistentContext(profile, { executablePath: BRAVE, viewport: { width: 1440, height: 900 } });
  const page = ctx.pages()[0] ?? await ctx.newPage();
  page.on('pageerror', (e) => console.log(`[${label}] page error`, String(e).slice(0, 200)));
  await page.goto(`${WEB}/app`);
  await page.waitForSelector('.cell', { timeout: 60000 });
  if (await page.locator('.welcome').count()) await page.getByRole('button', { name: /Skip|Open my diary/ }).first().click();
  return { ctx, page, label };
}
async function tab(b, name) { await b.page.locator('.sidebar').getByRole('button', { name, exact: true }).click(); await sleep(250); }
/** Waits until `fn(arg)` is true in the page; returns the time it became true. */
async function webSees(b, fn, arg, timeout = 60000) {
  try { await b.page.waitForFunction(fn, arg, { polling: 40, timeout }); return Date.now(); } catch { return null; }
}
const cardWith = (title) => [...document.querySelectorAll('.day-panel .card')].find((c) => c.querySelector('.t')?.textContent === title);
const hasCard = new Function('title', `return !!(${cardWith.toString()})(title)`);
const noCard = new Function('title', `return !(${cardWith.toString()})(title)`);
const cardMood = new Function('a', `const c = (${cardWith.toString()})(a.title); return !!c && !!c.querySelector('[title="' + a.mood + '"]')`);
const cardPhoto = new Function('a', `const c = (${cardWith.toString()})(a.title); const img = c && c.querySelector('.thumb img'); return a.want === 'none' ? !!c && !img : !!img && img.complete && img.naturalWidth > 0 && img.src !== a.not`);
const taskState = new Function('a', `const r = [...document.querySelectorAll('.task')].filter((t) => t.querySelector('.title b')?.textContent === a.title); return a.count ? r.length >= a.count : r.some((t) => t.classList.contains('done') === a.done)`);
const taskMeta = new Function('a', `const r = [...document.querySelectorAll('.task')].find((t) => t.querySelector('.title b')?.textContent === a.title); return !!r && (r.querySelector('.task-meta')?.textContent ?? '').includes(a.text)`);
const chipNamed = new Function('name', `return [...document.querySelectorAll('.chip')].some((c) => c.textContent.trim() === name)`);
const sidebarName = new Function('name', `return document.querySelector('.sidebar .me')?.textContent.includes(name)`);
const avatarIs = new Function('n', `return !!document.querySelector('.sidebar .me img')?.getAttribute('src')?.includes('avatar-' + n)`);
const themeIs = new Function('t', `return document.documentElement.dataset.theme === t`);

async function webCreateEntry(b, title) {
  await b.page.locator('.sidebar .btn.new').click();
  await b.page.fill('.sheet .title-input', title);
  const t0 = Date.now();
  await b.page.locator('.sheet').getByRole('button', { name: 'Save', exact: true }).click();
  return t0;
}
async function webEdit(b, title, change) {
  await b.page.locator('.day-panel .card', { has: b.page.locator('.t', { hasText: title }) }).first().click();
  await b.page.locator('.sheet').getByRole('button', { name: 'Edit' }).click();
  await change(b.page);
  const t0 = Date.now();
  await b.page.locator('.sheet').getByRole('button', { name: 'Save', exact: true }).click();
  return t0;
}
async function webTrash(b, title) {
  await b.page.locator('.day-panel .card', { has: b.page.locator('.t', { hasText: title }) }).first().click();
  await b.page.locator('.sheet').getByRole('button', { name: 'More' }).click();
  const t0 = Date.now();
  await b.page.getByRole('menuitem', { name: 'Delete' }).click();
  return t0;
}

function record(row) {
  const show = (v) => (v === null ? 'MISSED' : `${v} ms`);
  console.log(`${row.id.padEnd(4)} ${row.change.padEnd(42)} ${row.from.padEnd(7)} → ${Object.entries(row.latency).map(([k, v]) => `${k} ${show(v)}`).join(' · ')}`);
  results.push(row);
}
const lat = (t1, t0) => (t1 === null ? null : t1 - t0);

// MARK: Run
mkdirSync(dirname(args.out), { recursive: true });
phoneLaunch();
await phoneSees(/probe-start/, Date.now() - 5000, 30000);
const A = await openBrowser(profileA, 'webA');
const B = await openBrowser(profileB, 'webB');
await sleep(4000);
const today = new Date().toISOString().slice(0, 10);
for (const b of [A, B]) await tab(b, 'Calendar');

// Entries
let title = T('E1');
let t0 = await webCreateEntry(A, title);
record({ id: 'E1', change: 'create entry', from: 'webA', latency: { webB: lat(await webSees(B, hasCard, title), t0), iPhone: lat(await phoneSees(new RegExp(`applied entry .*"${title}"`), t0), t0) } });

let renamed = T('E1b');
t0 = phone(`entry.rename ${title}=>${renamed}`);
record({ id: 'E2', change: 'rename entry', from: 'iPhone', latency: { webA: lat(await webSees(A, hasCard, renamed), t0), webB: lat(await webSees(B, hasCard, renamed), t0) } });

t0 = await webTrash(B, renamed);
record({ id: 'E3', change: 'delete entry (to Recently Deleted)', from: 'webB', latency: { webA: lat(await webSees(A, noCard, renamed), t0), iPhone: lat(await phoneSees(new RegExp(`applied entry .*"${renamed}".*trashed`), t0), t0) } });

t0 = phone(`entry.restore ${renamed}`);
record({ id: 'E4', change: 'restore entry', from: 'iPhone', latency: { webA: lat(await webSees(A, hasCard, renamed), t0), webB: lat(await webSees(B, hasCard, renamed), t0) } });

t0 = await webEdit(A, renamed, async (p) => { await p.locator('.mood-picker').getByRole('radio', { name: /Good/ }).click(); });
record({ id: 'E5', change: 'set mood (Good)', from: 'webA', latency: { webB: lat(await webSees(B, cardMood, { title: renamed, mood: 'Good' }), t0), iPhone: lat(await phoneSees(new RegExp(`applied entry .*"${renamed}".*mood=4`), t0), t0) } });

// Photos
t0 = phone(`entry.photo.add ${renamed}`);
record({ id: 'P1', change: 'add photo (encrypted upload, 3 renditions)', from: 'iPhone', latency: { webA: lat(await webSees(A, cardPhoto, { title: renamed }), t0), webB: lat(await webSees(B, cardPhoto, { title: renamed }), t0) } });
const firstSrc = await A.page.evaluate((t) => [...document.querySelectorAll('.day-panel .card')].find((c) => c.querySelector('.t')?.textContent === t)?.querySelector('.thumb img')?.src, renamed);
t0 = phone(`entry.photo.replace ${renamed}`);
record({ id: 'P2', change: 'replace photo', from: 'iPhone', latency: { webA: lat(await webSees(A, cardPhoto, { title: renamed, not: firstSrc }), t0) } });
t0 = await webEdit(B, renamed, async (p) => { await p.locator('.sheet .photo-strip .x').first().click(); });
record({ id: 'P3', change: 'remove photo', from: 'webB', latency: { webA: lat(await webSees(A, cardPhoto, { title: renamed, want: 'none' }), t0), iPhone: lat(await phoneSees(/applied entryPhoto .* deleted=true|applied entryPhoto [0-9a-f]{8}$/, t0), t0) } });
const png = join(dirname(args.out), `sync-photo-${RUN}.jpg`);
execFileSync('cp', [join(dirname(new URL(import.meta.url).pathname), '..', 'ios', 'FolioTests', 'Resources', 'sample-diary-page.jpg'), png]);
t0 = await webEdit(A, renamed, async (p) => { await p.setInputFiles('.sheet .toolbar input[type=file]', png); await p.waitForSelector('.sheet .photo-strip img'); });
record({ id: 'P4', change: 'add photo from the web', from: 'webA', latency: { webB: lat(await webSees(B, cardPhoto, { title: renamed }), t0), iPhone: lat(await phoneSees(/blob-down /, t0, 90000), t0) } });

// Tasks
for (const b of [A, B]) await tab(b, 'To-do');
const task = T('T1');
await A.page.fill('#quick-add', `${task} today`);
t0 = Date.now();
await A.page.press('#quick-add', 'Enter');
record({ id: 'T1', change: 'create task (quick add "today")', from: 'webA', latency: { webB: lat(await webSees(B, taskState, { title: task, done: false }), t0), iPhone: lat(await phoneSees(new RegExp(`applied task .*"${task}"`), t0), t0) } });
t0 = phone(`task.tick ${task}`);
record({ id: 'T2', change: 'tick task', from: 'iPhone', latency: { webA: lat(await webSees(A, taskState, { title: task, done: true }), t0), webB: lat(await webSees(B, taskState, { title: task, done: true }), t0) } });
await B.page.locator('.task', { has: B.page.locator('.title b', { hasText: task }) }).locator('.tick').first().click();
t0 = Date.now();
record({ id: 'T3', change: 'untick task (in Completed)', from: 'webB', latency: { webA: lat(await webSees(A, taskState, { title: task, done: false }), t0), iPhone: lat(await phoneSees(new RegExp(`applied task .*"${task}".*isCompleted=0`), t0), t0) } });
t0 = phone(`task.subtask ${task}=>${T('T1-sub')}`);
record({ id: 'T4', change: 'add subtask', from: 'iPhone', latency: { webA: lat(await webSees(A, taskMeta, { title: task, text: '0/1' }), t0), webB: lat(await webSees(B, taskMeta, { title: task, text: '0/1' }), t0) } });
phone(`task.repeat ${task}`);
await sleep(2600);
t0 = phone(`task.tick ${task}`);
record({ id: 'T5', change: 'tick a daily repeating task → next one appears', from: 'iPhone', latency: { webA: lat(await webSees(A, taskState, { title: task, count: 2 }), t0), webB: lat(await webSees(B, taskState, { title: task, count: 2 }), t0) } });
// The web ticks after 1.2 s (SPEC §6.7); its push starts then.
await A.page.locator('.task:not(.done)', { has: A.page.locator('.title b', { hasText: task }) }).locator('.tick').first().click();
t0 = Date.now() + 1200;
record({ id: 'T6', change: 'tick on the web (1.2 s rule) — repeat spawns once', from: 'webA', latency: { iPhone: lat(await phoneSees(new RegExp(`applied task .*"${task}".*isCompleted=1`), t0 - 1200), t0), webB: lat(await webSees(B, taskState, { title: task, count: 3 }), t0) } });

// Categories
const category = T('C1');
t0 = phone(`category.create ${category}`);
record({ id: 'C1', change: 'create category', from: 'iPhone', latency: { webA: lat(await webSees(A, chipNamed, category), t0), webB: lat(await webSees(B, chipNamed, category), t0) } });
const category2 = `${category}x`;
t0 = phone(`category.rename ${category}=>${category2}`);
record({ id: 'C2', change: 'rename category', from: 'iPhone', latency: { webA: lat(await webSees(A, chipNamed, category2), t0), webB: lat(await webSees(B, chipNamed, category2), t0) } });

// Settings
const avatar = String(2 + (parseInt(RUN, 36) % 23)).padStart(2, '0'); // a different one each run
t0 = phone(`settings.avatar folio:${avatar}`);
record({ id: 'S1', change: `profile picture (Folio avatar ${avatar})`, from: 'iPhone', latency: { webA: lat(await webSees(A, avatarIs, avatar), t0), webB: lat(await webSees(B, avatarIs, avatar), t0) } });
const name = `SYNC ${RUN}`;
t0 = phone(`settings.name ${name}`);
record({ id: 'S2', change: 'display name', from: 'iPhone', latency: { webA: lat(await webSees(A, sidebarName, name), t0), webB: lat(await webSees(B, sidebarName, name), t0) } });
await tab(A, 'Profile');
await A.page.locator('select').first().selectOption('dark');
t0 = Date.now();
record({ id: 'S3', change: 'theme → Dark', from: 'webA', latency: { webB: lat(await webSees(B, themeIs, 'dark'), t0), iPhone: lat(await phoneSees(/applied settings .*appearance=dark/, t0), t0) } });
await A.page.locator('select').first().selectOption('system');
await tab(A, 'Calendar'); await tab(B, 'Calendar');

// Offline → online
const off = T('O1');
await B.ctx.setOffline(true);
t0 = await webCreateEntry(A, off);
await sleep(5000);
const missedWhileOffline = await B.page.evaluate(hasCard, off);
await B.ctx.setOffline(false);
const back = Date.now();
record({ id: 'O1', change: 'webB offline 5 s while webA writes; then online', from: 'webA', latency: { 'webB after online': lat(await webSees(B, hasCard, off), back), iPhone: lat(await phoneSees(new RegExp(`applied entry .*"${off}"`), t0), t0) }, note: missedWhileOffline ? 'B saw it while offline (unexpected)' : 'nothing reached B while offline' });

phone('sync.pause');
await sleep(500);
const off2 = T('O2');
t0 = phone(`entry.create ${off2}`);
await sleep(5000);
const leaked = await A.page.evaluate(hasCard, off2);
const resumed = phone('sync.resume');
record({ id: 'O2', change: 'iPhone offline (sync paused) writes; then online', from: 'iPhone', latency: { 'webA after online': lat(await webSees(A, hasCard, off2), resumed), 'webB after online': lat(await webSees(B, hasCard, off2), resumed) }, note: leaked ? 'reached web while paused (unexpected)' : 'nothing left the iPhone while paused' });

// Conflict: both edit the same entry while apart; the later edit wins everywhere (last-writer-wins).
phone('sync.pause');
await sleep(500);
const lose = T('X-web'), win = T('X-phone');
await webEdit(A, off2, async (p) => { await p.fill('.sheet .title-input', lose); });
await sleep(1500);
phone(`entry.rename ${off2}=>${win}`);
await sleep(500);
t0 = phone('sync.resume');
record({ id: 'X1', change: 'conflict: web edits, then iPhone edits offline → later wins', from: 'both', latency: { webA: lat(await webSees(A, hasCard, win), t0), webB: lat(await webSees(B, hasCard, win), t0), 'iPhone pushed': lat(await phoneSees(/pushed entry/, t0), t0) } });
const loserGone = await webSees(A, noCard, lose, 15000);
results[results.length - 1].note = loserGone ? `"${lose}" is gone everywhere` : 'the losing title is still showing';

writeFileSync(args.out, JSON.stringify({ run: RUN, web: WEB, api: API, date: new Date().toISOString(), rows: results }, null, 2));
await A.ctx.close(); await B.ctx.close();
console.log(`\nWrote ${args.out}`);
