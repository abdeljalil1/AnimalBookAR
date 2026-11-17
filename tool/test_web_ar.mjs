#!/usr/bin/env node
// End-to-end test of the AR camera screen (app/assets/ar) in headless Chrome.
//
// Chrome's fake camera plays a video of the printed pages lying on a desk,
// each page followed by an empty desk. The test checks that
//   - all five animal models load,
//   - every page is found in order, and lost when it leaves the camera,
//   - the animal's sound plays when its page is found,
//   - dragging turns the animal and the mouse wheel resizes it,
//   - body-part dots show on the animal; tapping one shows its name,
//   - Hold keeps the stork on screen after its page leaves the camera,
//     and releasing Hold goes back to scanning,
//   - then, reloaded in quiz mode in French: the page is in French, a wrong
//     answer is refused, the right one counts,
//   - there are no page errors,
// and saves screenshots to tool/test-output/.
//
// Usage: node tool/test_web_ar.mjs        (needs Chrome and ffmpeg)
import { spawn, execFileSync } from 'node:child_process';
import { createServer } from 'node:http';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { extname, join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const AR = join(ROOT, 'app', 'assets', 'ar');
const OUT = join(ROOT, 'tool', 'test-output');
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const PAGES = ['horse', 'fox', 'flamingo', 'parrot', 'stork'];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const failures = [];
const check = (ok, what) => { console.log(`${ok ? 'PASS' : 'FAIL'}  ${what}`); if (!ok) failures.push(what); };

// ---- fake camera video ------------------------------------------------------
function makeVideo(dir) {
  const ff = (...args) => execFileSync('ffmpeg', ['-v', 'error', '-y', ...args]);
  const desk = 'color=c=0x7a5a3c:s=480x640:r=15';
  for (const id of PAGES) {
    ff('-f', 'lavfi', '-i', `${desk}:d=6`, '-loop', '1', '-t', '6', '-r', '15', '-i', join(ROOT, 'book', 'pages', `${id}.png`),
      '-filter_complex',
      // The page seen from a phone held over a book: top edge farther away.
      '[1:v]scale=-1:600,pad=iw+40:ih+40:20:20:color=0x7a5a3c,' +
      'perspective=x0=70:y0=0:x1=W-70:y1=0:x2=0:y2=H:x3=W:y3=H:sense=destination,scale=iw:ih*0.72[p];' +
      "[0:v][p]overlay=x='(W-w)/2+10*sin(t*1.3)':y='(H-h)/2+6*cos(t)'",
      '-pix_fmt', 'yuv420p', '-t', '6', join(dir, `${id}.mp4`));
  }
  ff('-f', 'lavfi', '-i', `${desk}:d=3`, '-pix_fmt', 'yuv420p', join(dir, 'blank.mp4'));
  ff('-f', 'lavfi', '-i', `${desk}:d=12`, '-pix_fmt', 'yuv420p', join(dir, 'blank-long.mp4')); // room for the Hold test
  const clips = PAGES.flatMap((p) => [p, 'blank']);
  clips[clips.length - 1] = 'blank-long';
  writeFileSync(join(dir, 'list.txt'), clips.map((n) => `file ${n}.mp4`).join('\n'));
  const y4m = join(dir, 'book.y4m');
  ff('-f', 'concat', '-safe', '0', '-i', join(dir, 'list.txt'), '-pix_fmt', 'yuv420p', '-f', 'yuv4mpegpipe', y4m);
  return y4m;
}

// ---- static server for the AR page -----------------------------------------
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json',
  '.glb': 'model/gltf-binary', '.m4a': 'audio/mp4', '.png': 'image/png', '.mind': 'application/octet-stream' };
function serve() {
  const server = createServer((req, res) => {
    const path = join(AR, decodeURIComponent(new URL(req.url, 'http://x').pathname));
    if (!path.startsWith(AR) || !existsSync(path)) { res.writeHead(404); res.end(); return; }
    try {
      const body = readFileSync(path.endsWith('/') ? join(path, 'index.html') : path);
      res.writeHead(200, { 'Content-Type': TYPES[extname(path)] || 'application/octet-stream' });
      res.end(body);
    } catch { res.writeHead(404); res.end(); }
  });
  return new Promise((ok) => server.listen(0, '127.0.0.1', () => ok(server)));
}

// ---- minimal Chrome DevTools Protocol client ----------------------------------
async function cdp(wsUrl) {
  const ws = new WebSocket(wsUrl);
  await new Promise((ok, fail) => { ws.onopen = ok; ws.onerror = fail; });
  let id = 0;
  const waiting = new Map();
  const listeners = [];
  ws.onmessage = (m) => {
    const msg = JSON.parse(m.data);
    if (msg.id && waiting.has(msg.id)) { waiting.get(msg.id)(msg); waiting.delete(msg.id); }
    else listeners.forEach((l) => l(msg));
  };
  const send = (method, params = {}) => new Promise((ok, fail) => {
    const n = ++id;
    waiting.set(n, (msg) => (msg.error ? fail(new Error(method + ': ' + msg.error.message)) : ok(msg.result)));
    ws.send(JSON.stringify({ id: n, method, params }));
  });
  return { send, on: (l) => listeners.push(l), close: () => ws.close() };
}

async function main() {
  mkdirSync(OUT, { recursive: true });
  const work = mkdtempSync(join(tmpdir(), 'animal-ar-test-'));
  console.log('making fake camera video…');
  const y4m = makeVideo(work);
  const server = await serve();
  const url = `http://127.0.0.1:${server.address().port}/index.html?debug`;
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
    if (msg.method === 'Runtime.exceptionThrown') errors.push(msg.params.exceptionDetails.exception?.description || msg.params.exceptionDetails.text);
    if (msg.method === 'Runtime.consoleAPICalled' && msg.params.type === 'error') errors.push(msg.params.args.map((a) => a.value || a.description).join(' '));
  });
  await page.send('Runtime.enable');
  await page.send('Page.enable');
  await page.send('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 2, mobile: true });
  await page.send('Page.navigate', { url });

  const evalJs = async (expr) => (await page.send('Runtime.evaluate', { expression: expr, returnByValue: true })).result.value;
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

  // Watch the state for up to 60 s and note the order pages were found in.
  const seen = [];
  let last = null, st = null, gestureDone = false, partsDone = false, holdDone = false;
  const t0 = Date.now();
  while (Date.now() - t0 < 120000) {
    await sleep(250);
    st = await evalJs('JSON.stringify(window.__arState || null)').then((s) => JSON.parse(s));
    if (!st) continue;
    if (st.found && st.found !== last) {
      seen.push(st.found);
      console.log(`      found ${st.found} after ${((Date.now() - t0) / 1000).toFixed(1)}s`);
      await sleep(900); // let the model settle in and animate
      await shot(`found-${st.found}.png`);
    }
    if (!st.found && last) seen.push('lost');
    last = st.found;

    if (st.found === 'horse' && !partsDone) {
      partsDone = true;
      await sleep(400);
      const parts = await evalJs('JSON.stringify(window.__arState.parts)').then(JSON.parse);
      check(parts.visible.length >= 2, `body-part dots show on the horse (${parts.visible.join(', ')})`);
      const dot = await centerOf('.part-dot:not(.hidden)');
      if (dot) {
        await tap(dot.x, dot.y);
        await sleep(400);
        const sel = await evalJs('JSON.stringify({ s: window.__arState.parts.selected, label: !document.getElementById("part-label").classList.contains("hidden"), en: document.getElementById("part-en").textContent, other: document.getElementById("part-other").textContent })').then(JSON.parse);
        check(sel.s && sel.label && sel.en && sel.other.includes(' · '), `tapping a dot names the part (${sel.en} / ${sel.other})`);
        const sounds = await evalJs('window.__arState.soundsPlayed');
        check(sounds === 1, `tapping a dot selects it without replaying the sound (${sounds} sound)`);
        await shot('horse-part.png');
      } else {
        check(false, 'a visible body-part dot to tap');
      }
    }

    if (st.found === 'stork' && !holdDone) {
      holdDone = true;
      await sleep(700);
      const btn = await centerOf('#btn-hold');
      await tap(btn.x, btn.y);
      await sleep(300);
      const h1 = await evalJs('JSON.stringify(window.__arState)').then(JSON.parse);
      check(h1.phase === 'held' && h1.held, `Hold turns on (${h1.phase})`);
      await sleep(5500); // the stork page leaves the camera meanwhile
      const h2 = await evalJs('JSON.stringify(window.__arState)').then(JSON.parse);
      check(h2.phase === 'held' && h2.found === 'stork' && h2.parts.visible.length > 0,
        `the stork stays on screen after its page leaves (${h2.phase}, ${h2.parts.visible.length} parts in view)`);
      await shot('stork-held.png');
      await tap(btn.x, btn.y); // release
      await sleep(1000);
      const h3 = await evalJs('JSON.stringify(window.__arState)').then(JSON.parse);
      check(h3.phase === 'scanning' && !h3.held, `releasing Hold goes back to scanning (${h3.phase})`);
      continue;
    }

    if (st.found === 'horse' && !gestureDone) {
      gestureDone = true;
      const before = await evalJs('JSON.stringify(window.__arState.transform)').then(JSON.parse);
      // drag right with the mouse: turns the animal
      await page.send('Input.dispatchMouseEvent', { type: 'mousePressed', x: 195, y: 350, button: 'left', clickCount: 1 });
      for (let x = 195; x <= 315; x += 20) await page.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y: 350, button: 'left', buttons: 1 });
      await page.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: 315, y: 350, button: 'left', clickCount: 1 });
      // wheel up: makes it bigger
      await page.send('Input.dispatchMouseEvent', { type: 'mouseWheel', x: 195, y: 350, deltaX: 0, deltaY: -300 });
      await sleep(300);
      const after = await evalJs('JSON.stringify(window.__arState.transform)').then(JSON.parse);
      check(after && before && after.turn > before.turn + 0.5, `drag turns the animal (turn ${before?.turn} -> ${after?.turn})`);
      check(after && before && after.scale > before.scale * 1.1, `wheel resizes the animal (scale ${before?.scale} -> ${after?.scale})`);
      await shot('horse-turned-bigger.png');
    }
    if (seen.includes(PAGES.at(-1)) && seen.at(-1) === 'lost') break;
  }

  // ---- second pass: quiz mode, in French ----
  await page.send('Page.navigate', { url: url + '&mode=quiz&lang=fr' });
  let q = null;
  const tq = Date.now();
  while (Date.now() - tq < 60000) {
    await sleep(300);
    q = await evalJs('JSON.stringify(window.__arState || null)').then((x) => JSON.parse(x)).catch(() => null);
    if (q && q.quiz && q.quiz.target && Object.keys(q.partsAt || {}).length >= 2) break;
  }
  const texts = await evalJs('JSON.stringify({ btn: document.getElementById("btn-sound").textContent, quiz: document.getElementById("quiz-text").textContent, hidden: document.getElementById("quiz").classList.contains("hidden") })').then(JSON.parse);
  check(texts.btn.includes('Son') && texts.quiz.startsWith('Trouve') && !texts.hidden,
    `quiz mode asks in French (${q?.found}: "${texts.quiz}", button "${texts.btn}")`);
  if (q && q.quiz && q.quiz.target) {
    const target = q.quiz.target;
    const wrongId = Object.keys(q.partsAt).find((id) => id !== target);
    if (wrongId) {
      await tap(...q.partsAt[wrongId]);
      await sleep(300);
      const w = await evalJs('JSON.stringify({ cls: document.getElementById("quiz").className, correct: window.__arState.quiz.correct })').then(JSON.parse);
      check(w.cls.includes('wrong') && w.correct === 0, `a wrong answer is refused (${wrongId} for ${target})`);
      await sleep(1800);
    }
    const now = await evalJs('JSON.stringify(window.__arState.partsAt)').then(JSON.parse);
    if (now[target]) {
      await tap(...now[target]);
      await sleep(500);
      const r = await evalJs('JSON.stringify({ cls: document.getElementById("quiz").className, text: document.getElementById("quiz-text").textContent, correct: window.__arState.quiz.correct })').then(JSON.parse);
      check(r.correct === 1 && r.cls.includes('right') && r.text.startsWith('Bravo'), `the right answer counts ("${r.text}")`);
      await shot('quiz-right.png');
    } else {
      check(false, `the quiz target ${target} is on screen to tap`);
    }
  } else {
    check(false, 'quiz mode asks a question');
  }

  console.log('      final state', JSON.stringify(st));
  check(st && st.modelsLoaded === 5, `all 5 models loaded (${st?.modelsLoaded})`);
  const expected = PAGES.flatMap((p) => [p, 'lost']).join(' > ');
  check(seen.join(' > ') === expected, `pages found and lost in order (${seen.join(' > ')})`);
  check(st && st.soundsPlayed >= PAGES.length, `a sound played for each page found (${st?.soundsPlayed})`);
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
