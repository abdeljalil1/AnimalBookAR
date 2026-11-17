#!/usr/bin/env node
// End-to-end test of the AR camera screen with the Cars book (?book=cars),
// in headless Chrome with a fake camera showing the car, fire truck and
// ambulance pages. Checks that
//   - the nine vehicle models load and the pages are found in order,
//   - the texts are the vehicle ones ("Drive", "Help"),
//   - Drive moves the car forward and turns its wheels,
//   - "What does it need?" takes fuel and refuses a wrong item,
//   - "Who helps?" (asked for the fire truck): the car page is a wrong
//     answer, the fire truck page the right one,
//   - there are no page errors.
// Usage: node tool/test_cars_ar.mjs        (needs Chrome and ffmpeg)
import { spawn } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { ROOT, AR, CHROME, sleep, makeVideo, serve, cdp } from './ar_test_lib.mjs';

const OUT = join(ROOT, 'tool', 'test-output');
const PAGES = ['car', 'firetruck', 'ambulance'];
const ITEMS = JSON.parse(readFileSync(join(AR, 'books', 'cars', 'items.json'))).length;
const failures = [];
const check = (ok, what) => { console.log(`${ok ? 'PASS' : 'FAIL'}  ${what}`); if (!ok) failures.push(what); };

async function main() {
  mkdirSync(OUT, { recursive: true });
  const work = mkdtempSync(join(tmpdir(), 'cars-ar-test-'));
  console.log('making fake camera video…');
  const y4m = makeVideo(work, PAGES, join(ROOT, 'book', 'cars', 'pages'), 'car');
  const server = await serve();
  const url = `http://127.0.0.1:${server.address().port}/index.html?debug&book=cars`;
  const chrome = spawn(CHROME, [
    '--headless=new', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
    '--use-fake-ui-for-media-stream', '--use-fake-device-for-media-stream',
    `--use-file-for-fake-video-capture=${y4m}`, '--autoplay-policy=no-user-gesture-required',
    '--remote-debugging-port=0', `--user-data-dir=${join(work, 'profile')}`,
    '--window-size=390,844', 'about:blank',
  ], { stdio: ['ignore', 'ignore', 'pipe'] });
  const wsBrowser = await new Promise((ok) => {
    let buf = '';
    chrome.stderr.on('data', (d) => { buf += d; const m = buf.match(/DevTools listening on (ws:\S+)/); if (m) ok(m[1]); });
  });
  const port = new URL(wsBrowser).port;
  const targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  const page = await cdp(targets.find((t) => t.type === 'page').webSocketDebuggerUrl);
  const errors = [];
  page.on((msg) => {
    if (msg.method === 'Runtime.exceptionThrown') {
      const d = msg.params.exceptionDetails;
      errors.push(`${d.exception?.description || d.text} @ ${d.url || ''}:${d.lineNumber}`);
    }
    if (msg.method === 'Runtime.consoleAPICalled' && msg.params.type === 'error') errors.push('console: ' + msg.params.args.map((a) => a.value ?? a.description).join(' '));
  });
  await page.send('Runtime.enable');
  await page.send('Page.enable');
  await page.send('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 2, mobile: true });
  await page.send('Page.navigate', { url });

  const evalJs = async (expr) => (await page.send('Runtime.evaluate', { expression: expr, returnByValue: true })).result.value;
  const state = () => evalJs('JSON.stringify(window.__arState || null)').then(JSON.parse).catch(() => null);
  const tap = async (x, y) => {
    await page.send('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 });
    await page.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', clickCount: 1 });
  };
  const centerOf = (selector) => evalJs(`(() => { const e = document.querySelector(${JSON.stringify(selector)});
    if (!e) return null; const r = e.getBoundingClientRect(); return JSON.stringify({ x: r.x + r.width / 2, y: r.y + r.height / 2 }); })()`)
    .then((s) => (s ? JSON.parse(s) : null));
  const shot = async (name) => {
    const { data } = await page.send('Page.captureScreenshot', { format: 'png' });
    writeFileSync(join(OUT, name), Buffer.from(data, 'base64'));
    console.log('      screenshot tool/test-output/' + name);
  };

  const seen = [];
  let last = null, st = null, carDone = false;
  const t0 = Date.now();
  while (Date.now() - t0 < 90000) {
    await sleep(250);
    st = await state();
    if (!st) continue;
    if (st.found && st.found !== last) {
      seen.push(st.found);
      console.log(`      found ${st.found} after ${((Date.now() - t0) / 1000).toFixed(1)}s`);
      await sleep(900);
      await shot(`cars-found-${st.found}.png`);
    }
    if (!st.found && last) seen.push('lost');
    last = st.found;

    if (st.found === 'car' && !carDone) {
      carDone = true;
      const labels = await evalJs('JSON.stringify({ move: document.getElementById("btn-move").textContent, feed: document.getElementById("btn-feed").textContent })').then(JSON.parse);
      check(labels.move.includes('Drive') && labels.feed.includes('Help'), `vehicle buttons (${labels.move}, ${labels.feed})`);
      const move = await centerOf('#btn-move');
      await tap(move.x, move.y);
      await sleep(700);
      const d1 = (await state()).drive;
      check(d1 && d1.id === 'car' && d1.z > 0.05, `Drive moves the car forward (z ${d1?.z})`);
      check(d1 && d1.wheels >= 3 && Math.abs(d1.angle) > 1, `the car's wheels turn (${d1?.wheels} wheels, angle ${d1?.angle})`);
      await shot('cars-drive.png');
      await sleep(2600);
      const d2 = (await state()).drive;
      check(d2 && Math.abs(d2.z) < 0.02, `the car comes back (z ${d2?.z})`);

      const help = await centerOf('#btn-feed');
      await tap(help.x, help.y);
      await sleep(250);
      const tray = (await state()).feed;
      check(tray && tray.on && tray.items.length === 6 && tray.items.includes('fuel'), `the tray shows 6 items with fuel (${tray?.items?.join(', ')})`);
      const fuel = await centerOf('.food[data-food="fuel"]');
      if (fuel) await tap(fuel.x, fuel.y);
      await sleep(400);
      const r1 = await evalJs('JSON.stringify({ f: window.__arState.feed, toast: document.getElementById("toast").textContent })').then(JSON.parse);
      check(r1.f.fed.includes('fuel') && r1.toast.startsWith('Thanks'), `the car takes fuel ("${r1.toast}")`);
      const wrongId = tray.items.find((f) => !['fuel', 'passengers', 'soap'].includes(f));
      const wrong = await centerOf(`.food[data-food="${wrongId}"]`);
      if (wrong) await tap(wrong.x, wrong.y);
      await sleep(400);
      const r2 = await evalJs('JSON.stringify({ f: window.__arState.feed, toast: document.getElementById("toast").textContent })').then(JSON.parse);
      check(!r2.f.fed.includes(wrongId) && r2.f.last.right === false && r2.toast.includes("don't need"), `the car refuses ${wrongId} ("${r2.toast}")`);
      await shot('cars-needs.png');
      await tap(help.x, help.y);
    }
    if (seen.includes(PAGES.at(-1)) && seen.at(-1) === 'lost') break;
  }
  console.log('      final state', JSON.stringify({ phase: st?.phase, models: st?.modelsLoaded, book: st?.book }));
  check(st && st.book === 'cars', `the Cars book is open (${st?.book})`);
  check(st && st.modelsLoaded === ITEMS, `all ${ITEMS} vehicle models loaded (${st?.modelsLoaded})`);
  const expected = PAGES.flatMap((p) => [p, 'lost']).join(' > ');
  check(seen.join(' > ') === expected, `pages found and lost in order (${seen.join(' > ')})`);

  // ---- second pass: "Who helps?" for the fire truck ----
  await page.send('Page.navigate', { url: url + '&mode=helps&soundTarget=firetruck' });
  let h = null, sawWrong = false;
  const th = Date.now();
  while (Date.now() - th < 60000) {
    await sleep(300);
    h = await evalJs('JSON.stringify({ q: window.__arState && window.__arState.soundQuiz, text: document.getElementById("quiz-text").textContent, cls: document.getElementById("quiz").className })').then(JSON.parse).catch(() => null);
    if (h && h.cls.includes('wrong')) sawWrong = true;
    if (h && h.q && h.q.correct >= 1) break;
  }
  check(sawWrong, 'Who helps?: the car page is a wrong answer for the fire');
  check(h && h.q && h.q.correct >= 1 && h.text.startsWith('Yes'), `Who helps?: the fire truck page is right ("${h?.text}")`);
  await shot('cars-helps.png');
  check(errors.length === 0, `no page errors${errors.length ? ': ' + errors.slice(0, 3).join(' | ') : ''}`);

  page.close();
  chrome.kill();
  server.close();
  await new Promise((ok) => (chrome.exitCode !== null ? ok() : chrome.once('exit', ok)));
  try { rmSync(work, { recursive: true, force: true }); } catch { /* Chrome may still hold files */ }
  console.log(failures.length ? `\n${failures.length} check(s) failed` : '\nall checks passed');
  process.exit(failures.length ? 1 : 0);
}

main().catch((e) => { console.error(e); process.exit(1); });
