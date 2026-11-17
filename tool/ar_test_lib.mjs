// Shared by the AR page tests (test_web_ar.mjs, test_cars_ar.mjs): a fake
// camera video of printed pages, a static server for app/assets/ar and a
// minimal Chrome DevTools Protocol client.
import { execFileSync } from 'node:child_process';
import { createServer } from 'node:http';
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { extname, join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

export const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
export const AR = join(ROOT, 'app', 'assets', 'ar');
export const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ---- fake camera video ------------------------------------------------------
export function makeVideo(dir, pages, pagesDir = join(ROOT, 'book', 'pages'), longFirst = 'horse') {
  const ff = (...args) => execFileSync('ffmpeg', ['-v', 'error', '-y', ...args]);
  const desk = 'color=c=0x7a5a3c:s=480x640:r=15';
  for (const id of pages) {
    const d = id === longFirst ? 14 : 6; // this page stays longer: most checks run on it
    ff('-f', 'lavfi', '-i', `${desk}:d=${d}`, '-loop', '1', '-t', String(d), '-r', '15', '-i', join(pagesDir, `${id}.png`),
      '-filter_complex',
      // The page seen from a phone held over a book: top edge farther away.
      '[1:v]scale=-1:600,pad=iw+40:ih+40:20:20:color=0x7a5a3c,' +
      'perspective=x0=70:y0=0:x1=W-70:y1=0:x2=0:y2=H:x3=W:y3=H:sense=destination,scale=iw:ih*0.72[p];' +
      "[0:v][p]overlay=x='(W-w)/2+10*sin(t*1.3)':y='(H-h)/2+6*cos(t)'",
      '-pix_fmt', 'yuv420p', '-t', String(d), join(dir, `${id}.mp4`));
  }
  ff('-f', 'lavfi', '-i', `${desk}:d=3`, '-pix_fmt', 'yuv420p', join(dir, 'blank.mp4'));
  ff('-f', 'lavfi', '-i', `${desk}:d=12`, '-pix_fmt', 'yuv420p', join(dir, 'blank-long.mp4')); // room for the Hold test
  const clips = pages.flatMap((p) => [p, 'blank']);
  clips[clips.length - 1] = 'blank-long';
  writeFileSync(join(dir, 'list.txt'), clips.map((n) => `file ${n}.mp4`).join('\n'));
  const y4m = join(dir, 'book.y4m');
  ff('-f', 'concat', '-safe', '0', '-i', join(dir, 'list.txt'), '-pix_fmt', 'yuv420p', '-f', 'yuv4mpegpipe', y4m);
  return y4m;
}

// ---- static server for the AR page -----------------------------------------
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json',
  '.glb': 'model/gltf-binary', '.m4a': 'audio/mp4', '.png': 'image/png', '.mind': 'application/octet-stream' };
export function serve() {
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
export async function cdp(wsUrl) {
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

