// Animal Book AR: camera screen.
// MindAR finds a book page in the camera image; three.js draws the matching
// animated animal standing on the page. Touch gestures turn, resize and move it.
//
// Page coordinates (MindAR anchor space): the page is the XY plane, its width
// is 1 unit, X points right, Y points to the top of the page, Z points out of
// the page toward the camera. Models are glTF (Y up), so they are rotated
// +90° about X to stand up on the page.
import * as THREE from './vendor/three/three.module.js';
import { GLTFLoader } from './vendor/three/addons/loaders/GLTFLoader.js';
import { MindARThree } from './vendor/mindar/mindar-image-three.prod.js';

const DEBUG = new URLSearchParams(location.search).has('debug');
const PAGE_HALF_W = 0.5;
const PAGE_HALF_H = 0.5 * (1755 / 1241); // pages are A4 portrait
const SOUND_REPEAT_MS = 8000; // replay the sound when a page is found again after this long
const LOST_GRACE_MS = 700; // keep the card up through short tracking drops
// Where animals stand: just below the photo, above the animal's name.
const HOME = new THREE.Vector3(0, -0.05, 0);

const $ = (id) => document.getElementById(id);

// Readable by tests (tool/test_web_ar.mjs) and handy when debugging.
const state = (window.__arState = {
  phase: 'loading', found: null, foundCount: 0, soundsPlayed: 0,
  modelsLoaded: 0, frames: 0, error: null,
});

// Messages to the Flutter app; a no-op in a normal browser.
function notifyApp(type, data = {}) {
  const bridge = window.flutter_inappwebview;
  if (bridge && bridge.callHandler) {
    try {
      const r = bridge.callHandler('arEvent', { type, ...data });
      if (r && r.catch) r.catch(() => {});
    } catch (_) { /* ignore */ }
  }
}

function setPhase(phase) {
  state.phase = phase;
  $('loading').classList.toggle('hidden', phase !== 'loading');
  $('scan').classList.toggle('hidden', phase !== 'scanning');
  $('card').classList.toggle('hidden', phase !== 'found');
  $('error').classList.toggle('hidden', phase !== 'error');
}

function showError(message) {
  state.error = message;
  $('error-text').textContent = message;
  setPhase('error');
  notifyApp('error', { message });
}

// A soft round shadow drawn on the page under each animal.
function makeShadowTexture() {
  const c = document.createElement('canvas');
  c.width = c.height = 128;
  const g = c.getContext('2d');
  const grad = g.createRadialGradient(64, 64, 4, 64, 64, 62);
  grad.addColorStop(0, 'rgba(0,0,0,0.45)');
  grad.addColorStop(1, 'rgba(0,0,0,0)');
  g.fillStyle = grad;
  g.fillRect(0, 0, 128, 128);
  return new THREE.CanvasTexture(c);
}

async function main() {
  const animals = await (await fetch('animals.json')).json();

  const mindar = new MindARThree({
    container: $('ar'),
    imageTargetSrc: 'targets.mind',
    maxTrack: 1,
    uiLoading: 'no', uiScanning: 'no', uiError: 'no',
    filterMinCF: 0.0001, filterBeta: 0.001, // steadier pose, a little more lag
    warmupTolerance: 3, missTolerance: 8,
  });
  const { renderer, scene, camera } = mindar;
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));

  scene.add(new THREE.HemisphereLight(0xffffff, 0x8d7b68, 2.4));
  const sun = new THREE.DirectionalLight(0xffffff, 1.8);
  sun.position.set(0.4, 1, 1.5);
  scene.add(sun);

  const loader = new GLTFLoader();
  const shadowTexture = makeShadowTexture();
  let current = null; // the entry whose page is in view
  let lostTimer = null;

  // One entry per animal: its anchor, transform groups, animations and sound.
  const entries = animals.map((a, i) => {
    const anchor = mindar.addAnchor(i);
    const root = new THREE.Group(); // user move (page X/Y)
    const spin = new THREE.Group(); // user turn (about the page normal)
    const scaler = new THREE.Group(); // user resize
    const pop = new THREE.Group(); // tap bounce
    const orient = new THREE.Group(); // glTF Y-up -> page Z-up
    const turn = new THREE.Group(); // which way the model faces; also the twirl
    orient.rotation.x = Math.PI / 2;
    turn.rotation.y = THREE.MathUtils.degToRad(a.turn || 0);
    root.position.copy(HOME);
    anchor.group.add(root);
    root.add(spin);
    spin.add(scaler);
    scaler.add(pop);
    pop.add(orient);
    orient.add(turn);

    const lifted = (a.lift || 0) > 0;
    const shadow = new THREE.Mesh(
      new THREE.PlaneGeometry(a.size * (lifted ? 0.5 : 0.8), a.size * (lifted ? 0.5 : 0.8)),
      new THREE.MeshBasicMaterial({ map: shadowTexture, transparent: true, depthWrite: false, opacity: lifted ? 0.5 : 1 }),
    );
    shadow.position.z = 0.002;
    scaler.add(shadow);

    const audio = new Audio(a.sound);
    audio.preload = 'auto';

    const entry = {
      a, i, anchor, root, spin, scaler, pop, turn, audio,
      model: null, mixer: null, actions: [], actionIndex: 0,
      lastSoundAt: -Infinity, popT: 0, twirlT: 0, baseTurn: turn.rotation.y,
    };

    loader.loadAsync(a.model).then((gltf) => {
      const model = gltf.scene;
      if (gltf.animations.length) {
        entry.mixer = new THREE.AnimationMixer(model);
        entry.actions = gltf.animations.map((clip) => entry.mixer.clipAction(clip));
        entry.actions[0].play();
        entry.mixer.update(0); // apply the first animated pose
      }
      // Measure the posed model: the base mesh of a morph-animated model (the
      // horse) and the unposed bones of a skinned one (the fox) give wrong sizes.
      model.updateMatrixWorld(true);
      model.traverse((o) => { if (o.isSkinnedMesh) o.skeleton.update(); });
      const box = new THREE.Box3().setFromObject(model, true);
      const size = box.getSize(new THREE.Vector3());
      const center = box.getCenter(new THREE.Vector3());
      const s = a.size / Math.max(size.x, size.z); // longest side = a.size page widths
      model.scale.setScalar(s);
      model.position.set(-center.x * s, -box.min.y * s + (a.lift || 0), -center.z * s);
      turn.add(model);
      entry.model = model;
      state.modelsLoaded++;
    }).catch((err) => console.error('model failed', a.model, err));

    anchor.onTargetFound = () => onFound(entry);
    anchor.onTargetLost = () => onLost(entry);
    return entry;
  });

  function showCard(a) {
    $('card').style.setProperty('--c', a.color);
    $('name-en').textContent = a.en;
    $('name-fr').textContent = a.fr;
    $('name-ar').textContent = a.ar;
    $('fact').textContent = a.fact_en;
  }

  function playSound(entry) {
    entry.lastSoundAt = performance.now();
    entry.popT = 0.45;
    const au = entry.audio;
    au.currentTime = 0;
    au.play().then(() => { state.soundsPlayed++; }).catch(() => {
      // Autoplay blocked (only in a normal browser): the Sound button still works.
    });
  }

  function onFound(entry) {
    clearTimeout(lostTimer);
    const isNew = current !== entry;
    current = entry;
    state.found = entry.a.id;
    state.foundCount++;
    showCard(entry.a);
    setPhase('found');
    if (isNew || performance.now() - entry.lastSoundAt > SOUND_REPEAT_MS) playSound(entry);
    notifyApp('found', { id: entry.a.id });
  }

  function onLost(entry) {
    clearTimeout(lostTimer);
    lostTimer = setTimeout(() => {
      if (current === entry && !entry.anchor.group.visible) {
        state.found = null;
        setPhase('scanning');
        notifyApp('lost', { id: entry.a.id });
      }
    }, LOST_GRACE_MS);
  }

  function nextMove(entry) {
    if (entry.actions.length > 1) {
      entry.actions[entry.actionIndex].fadeOut(0.3);
      entry.actionIndex = (entry.actionIndex + 1) % entry.actions.length;
      entry.actions[entry.actionIndex].reset().fadeIn(0.3).play();
    } else {
      entry.twirlT = 1.2; // a full turn in place
    }
  }

  function reset(entry) {
    entry.root.position.copy(HOME);
    entry.spin.rotation.z = 0;
    entry.scaler.scale.setScalar(1);
  }

  $('btn-sound').addEventListener('click', () => current && playSound(current));
  $('btn-move').addEventListener('click', () => current && nextMove(current));
  $('btn-reset').addEventListener('click', () => current && reset(current));

  // ---- Gestures -----------------------------------------------------------
  const container = $('ar');
  const pointers = new Map();
  const raycaster = new THREE.Raycaster();
  const ndc = new THREE.Vector2();
  const plane = new THREE.Plane();
  let gesture = null;

  function toNdc(x, y) {
    const r = renderer.domElement.getBoundingClientRect();
    ndc.set(((x - r.left) / r.width) * 2 - 1, -((y - r.top) / r.height) * 2 + 1);
    raycaster.setFromCamera(ndc, camera);
  }

  // Where a screen point lands on the current page, in page coordinates.
  function pageHit(x, y) {
    if (!current) return null;
    toNdc(x, y);
    const g = current.anchor.group;
    g.updateMatrixWorld(true);
    const normal = new THREE.Vector3(0, 0, 1).transformDirection(g.matrixWorld);
    const origin = new THREE.Vector3().setFromMatrixPosition(g.matrixWorld);
    plane.setFromNormalAndCoplanarPoint(normal, origin);
    const p = raycaster.ray.intersectPlane(plane, new THREE.Vector3());
    return p ? g.worldToLocal(p) : null;
  }

  function hitsAnimal(x, y) {
    if (!current || !current.model) return false;
    toNdc(x, y);
    const box = new THREE.Box3().setFromObject(current.model).expandByScalar(0.02);
    return raycaster.ray.intersectsBox(box);
  }

  function beginGesture() {
    const pts = [...pointers.values()];
    if (!current || pts.length === 0) { gesture = null; return; }
    if (pts.length === 1) {
      gesture = { kind: 'turn', x0: pts[0].x, rot0: current.spin.rotation.z };
    } else {
      const [p, q] = pts;
      const mid = { x: (p.x + q.x) / 2, y: (p.y + q.y) / 2 };
      gesture = {
        kind: 'pinch',
        d0: Math.hypot(p.x - q.x, p.y - q.y) || 1,
        scale0: current.scaler.scale.x,
        hit0: pageHit(mid.x, mid.y),
        pos0: current.root.position.clone(),
      };
    }
  }

  function updateGesture() {
    if (!gesture || !current) return;
    const pts = [...pointers.values()];
    if (gesture.kind === 'turn' && pts.length === 1) {
      current.spin.rotation.z = gesture.rot0 + (pts[0].x - gesture.x0) * 0.012;
    } else if (gesture.kind === 'pinch' && pts.length >= 2) {
      const [p, q] = pts;
      const d = Math.hypot(p.x - q.x, p.y - q.y);
      current.scaler.scale.setScalar(THREE.MathUtils.clamp(gesture.scale0 * d / gesture.d0, 0.35, 3));
      const hit = pageHit((p.x + q.x) / 2, (p.y + q.y) / 2);
      if (hit && gesture.hit0) {
        const pos = gesture.pos0.clone().add(hit.sub(gesture.hit0));
        pos.x = THREE.MathUtils.clamp(pos.x, -PAGE_HALF_W, PAGE_HALF_W);
        pos.y = THREE.MathUtils.clamp(pos.y, -PAGE_HALF_H, PAGE_HALF_H);
        pos.z = 0;
        current.root.position.copy(pos);
      }
    }
  }

  container.addEventListener('pointerdown', (e) => {
    container.setPointerCapture(e.pointerId);
    pointers.set(e.pointerId, { x: e.clientX, y: e.clientY, x0: e.clientX, y0: e.clientY, t0: performance.now() });
    beginGesture();
  });
  container.addEventListener('pointermove', (e) => {
    const p = pointers.get(e.pointerId);
    if (!p) return;
    p.x = e.clientX; p.y = e.clientY;
    updateGesture();
  });
  const endPointer = (e) => {
    const p = pointers.get(e.pointerId);
    if (!p) return;
    const wasSingle = pointers.size === 1;
    pointers.delete(e.pointerId);
    const moved = Math.hypot(p.x - p.x0, p.y - p.y0);
    if (wasSingle && moved < 10 && performance.now() - p.t0 < 350 && hitsAnimal(p.x, p.y)) {
      playSound(current);
    }
    beginGesture(); // re-baseline with the fingers still down
  };
  container.addEventListener('pointerup', endPointer);
  container.addEventListener('pointercancel', endPointer);
  container.addEventListener('wheel', (e) => {
    if (!current) return;
    e.preventDefault();
    const s = current.scaler.scale.x * Math.exp(-e.deltaY * 0.001);
    current.scaler.scale.setScalar(THREE.MathUtils.clamp(s, 0.35, 3));
  }, { passive: false });

  // ---- Render loop ----------------------------------------------------------
  const clock = new THREE.Clock();
  let fpsFrames = 0, fpsT = performance.now(), fps = 0;
  function frame() {
    const dt = Math.min(clock.getDelta(), 0.1);
    for (const e of entries) {
      if (!e.anchor.group.visible) continue;
      if (e.mixer) e.mixer.update(dt);
      if (e.popT > 0) {
        e.popT = Math.max(0, e.popT - dt);
        e.pop.scale.setScalar(1 + 0.18 * Math.sin((e.popT / 0.45) * Math.PI));
      }
      if (e.twirlT > 0) {
        e.twirlT = Math.max(0, e.twirlT - dt);
        e.turn.rotation.y = e.baseTurn + (1 - e.twirlT / 1.2) * Math.PI * 2;
      }
    }
    renderer.render(scene, camera);
    state.frames++;
    if (current) {
      state.transform = {
        turn: +current.spin.rotation.z.toFixed(3),
        scale: +current.scaler.scale.x.toFixed(3),
        x: +current.root.position.x.toFixed(3),
        y: +current.root.position.y.toFixed(3),
      };
    }
    if (DEBUG) {
      fpsFrames++;
      const now = performance.now();
      if (now - fpsT > 500) {
        fps = Math.round((fpsFrames * 1000) / (now - fpsT));
        fpsFrames = 0; fpsT = now;
        $('debug').textContent = `${state.phase} ${state.found || '-'}\n${fps} fps · models ${state.modelsLoaded}/${entries.length}`;
      }
    }
  }

  async function startAr() {
    setPhase('loading');
    await mindar.start();
    renderer.setAnimationLoop(frame);
    setPhase('scanning');
    notifyApp('ready');
  }

  // Called by the Flutter app when it goes to the background / comes back.
  window.arPause = () => {
    renderer.setAnimationLoop(null);
    try { mindar.stop(); } catch (_) { /* already stopped */ }
  };
  window.arResume = () => startAr().catch(() => location.reload());

  if (DEBUG) $('debug').classList.remove('hidden');
  try {
    await startAr();
  } catch (err) {
    console.error(err);
    const name = err && err.name;
    showError(name === 'NotAllowedError'
      ? 'Camera permission is off. Allow the camera for Animal Book AR, then try again.'
      : 'The camera could not start. Close other camera apps and try again.');
  }
}

main().catch((err) => {
  console.error(err);
  showError('Something went wrong while loading: ' + (err && err.message ? err.message : err));
});
