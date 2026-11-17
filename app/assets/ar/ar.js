// Animal Book AR: camera screen.
// MindAR finds a book page in the camera image; three.js draws the matching
// animated animal standing on the page. Touch gestures turn, tip, resize and
// move it. Body parts (head, tail, wings...) show as dots; aim the target in
// the middle of the screen at one (or tap it) to see its name in English,
// French and Arabic. "Hold" keeps the animal on screen when the page leaves
// the camera; turning the phone then looks around it (gyroscope).
//
// Page coordinates (MindAR anchor space): the page is the XY plane, its width
// is 1 unit, X points right, Y points to the top of the page, Z points out of
// the page toward the camera. Models are glTF (Y up), so they are rotated
// +90° about X to stand up on the page. The MindAR camera sits at the origin;
// anchors move, the camera does not.
import * as THREE from './vendor/three/three.module.js';
import { GLTFLoader } from './vendor/three/addons/loaders/GLTFLoader.js';
import { MindARThree } from './vendor/mindar/mindar-image-three.prod.js';

const params = new URLSearchParams(location.search);
const DEBUG = params.has('debug');
const LANG = ['en', 'fr', 'ar'].includes(params.get('lang')) ? params.get('lang') : 'en';
const QUIZ = params.get('mode') === 'quiz'; // level 3: "Find the tail!"
const QUIZ_GOAL = 3; // right answers per animal
const QUIZ_DWELL_MS = 400; // aim at the right part this long to answer
const PAGE_HALF_W = 0.5;
const PAGE_HALF_H = 0.5 * (1755 / 1241); // pages are A4 portrait
const SOUND_REPEAT_MS = 8000; // replay the sound when a page is found again after this long
const LOST_GRACE_MS = 700; // keep the card up through short tracking drops
const HOME = new THREE.Vector3(0, -0.05, 0); // where animals stand: above the animal's name
const MAX_SCALE = 5; // pinch zoom limit (close-ups of the face)
const AIM_Y = 0.42; // the aim target's height, as a share of the screen height
const OCCLUSION_MS = 150; // how often to check which body parts face the camera
const TAP_SELECT_MS = 4000; // a tapped part stays selected this long

const $ = (id) => document.getElementById(id);

// UI text in the three languages ({p} = a body part with its article).
const TEXT = {
  en: {
    loading: 'Starting the camera…', scan: 'Point the camera at an animal page',
    held: '✋ Holding: turn the phone to look around',
    hint: 'Aim the ◎ at a body part · 1 finger: turn and tip · 2 fingers: zoom, move',
    sound: 'Sound', move: 'Move', hold: 'Hold', page: 'Page', reset: 'Reset',
    find: 'Find {p}!', wrong: "That's {p}. Try again!", right: "Bravo! That's {p}!", quizDone: 'Quiz done! 🎉',
    newAnimal: 'New animal! +1 ★', newPart: '+1 ★', levelUp: 'Level {n} unlocked!', allDone: 'All levels done! 🏆',
    cameraOff: 'Camera permission is off. Allow the camera for Animal Book AR, then try again.',
    cameraFail: 'The camera could not start. Close other camera apps and try again.',
    loadFail: 'Something went wrong while loading: ',
  },
  fr: {
    loading: 'Démarrage de la caméra…', scan: "Vise une page d'animal avec la caméra",
    held: '✋ Tenu : tourne le téléphone pour regarder autour',
    hint: 'Vise ◎ une partie du corps · 1 doigt : tourner, pencher · 2 doigts : zoomer, déplacer',
    sound: 'Son', move: 'Bouger', hold: 'Tenir', page: 'Page', reset: 'Remettre',
    find: 'Trouve {p} !', wrong: "Ça, c'est {p}. Essaie encore !", right: "Bravo ! C'est {p} !", quizDone: 'Quiz fini ! 🎉',
    newAnimal: 'Nouvel animal ! +1 ★', newPart: '+1 ★', levelUp: 'Niveau {n} débloqué !', allDone: 'Tous les niveaux sont finis ! 🏆',
    cameraOff: "La caméra n'est pas autorisée. Autorise-la pour Animal Book AR, puis réessaie.",
    cameraFail: "La caméra n'a pas pu démarrer. Ferme les autres applis photo et réessaie.",
    loadFail: 'Erreur au chargement : ',
  },
  ar: {
    loading: 'تشغيل الكاميرا…', scan: 'وجّه الكاميرا نحو صفحة حيوان',
    held: '✋ مثبّت: أدر الهاتف لترى ما حوله',
    hint: 'صوّب ◎ نحو جزء من الجسم · إصبع: تدوير وإمالة · إصبعان: تكبير وتحريك',
    sound: 'صوت', move: 'حركة', hold: 'تثبيت', page: 'الصفحة', reset: 'إعادة',
    find: 'أين {p}؟', wrong: 'هذا {p}. حاول مرة أخرى!', right: 'أحسنت! هذا {p}!', quizDone: 'انتهى الاختبار! 🎉',
    newAnimal: 'حيوان جديد! +1 ★', newPart: '+1 ★', levelUp: 'فتحت المستوى {n}!', allDone: 'أكملت كل المستويات! 🏆',
    cameraOff: 'إذن الكاميرا متوقف. اسمح للتطبيق باستخدام الكاميرا ثم حاول مرة أخرى.',
    cameraFail: 'تعذّر تشغيل الكاميرا. أغلق تطبيقات الكاميرا الأخرى وحاول مرة أخرى.',
    loadFail: 'حدث خطأ أثناء التحميل: ',
  },
};
const t = (key, vars = {}) => TEXT[LANG][key].replace(/\{(\w+)\}/g, (_, k) => vars[k] ?? '');
const nameIn = (def, lang = LANG) => def[lang];
const partWithArticle = (def) => ({ en: 'the ' + def.en.toLowerCase(), fr: def.fr_def, ar: def.ar_def })[LANG];
const otherNames = (def) => ['en', 'fr', 'ar'].filter((l) => l !== LANG).map((l) => def[l]).join(' · ');

// Readable by tests (tool/test_web_ar.mjs) and handy when debugging.
const state = (window.__arState = {
  phase: 'loading', found: null, foundCount: 0, soundsPlayed: 0,
  modelsLoaded: 0, frames: 0, error: null, held: false, gyro: false,
  parts: { visible: [], selected: null },
});

// Ask the Flutter app (progress, stars); resolves to null in a normal browser.
async function ask(type, data = {}) {
  const bridge = window.flutter_inappwebview;
  if (!bridge || !bridge.callHandler) return null;
  try { return await bridge.callHandler('arEvent', { type, ...data }); } catch (_) { return null; }
}

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

// phase: loading | scanning | found | held | error
function setPhase(phase) {
  state.phase = phase;
  const showing = phase === 'found' || phase === 'held';
  $('loading').classList.toggle('hidden', phase !== 'loading');
  $('scan').classList.toggle('hidden', phase !== 'scanning');
  $('card').classList.toggle('hidden', !showing);
  $('aim').classList.toggle('hidden', !showing);
  $('parts').classList.toggle('hidden', !showing);
  $('held-badge').classList.toggle('hidden', phase !== 'held');
  $('quiz').classList.toggle('hidden', !QUIZ || !showing || !$('quiz-text').textContent);
  $('error').classList.toggle('hidden', phase !== 'error');
}

function showError(message) {
  state.error = message;
  $('error-text').textContent = message;
  setPhase('error');
  notifyApp('error', { message });
}

// ---- Feedback: toast, big celebration, confetti, chime ----------------------
let toastTimer = null;
function toast(text) {
  const el = $('toast');
  el.textContent = text;
  el.classList.remove('hidden', 'pop');
  void el.offsetWidth; // restart the animation
  el.classList.add('pop');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.add('hidden'), 1700);
}

function celebrate(text) {
  const el = $('celebrate');
  $('celebrate-text').textContent = text;
  el.classList.remove('hidden');
  confetti(220);
  tone([523, 659, 784, 1047, 1319]);
  setTimeout(() => el.classList.add('hidden'), 2600);
}

function confetti(n) {
  const canvas = $('confetti');
  const ctx = canvas.getContext('2d');
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  canvas.width = innerWidth * dpr;
  canvas.height = innerHeight * dpr;
  const colors = ['#ff6b6b', '#ffd166', '#06d6a0', '#4cc9f0', '#f72585', '#ffb703'];
  const bits = Array.from({ length: n }, () => ({
    x: innerWidth / 2 + (Math.random() - 0.5) * 120, y: innerHeight * 0.35,
    vx: (Math.random() - 0.5) * 9, vy: -Math.random() * 10 - 4,
    r: Math.random() * Math.PI, vr: (Math.random() - 0.5) * 0.3,
    w: 6 + Math.random() * 6, h: 4 + Math.random() * 4, c: colors[Math.floor(Math.random() * colors.length)],
  }));
  const t0 = performance.now();
  canvas.classList.remove('hidden');
  (function step(now) {
    const k = (now - t0) / 2200;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, innerWidth, innerHeight);
    for (const b of bits) {
      b.vy += 0.32; b.x += b.vx; b.y += b.vy; b.r += b.vr;
      ctx.save(); ctx.translate(b.x, b.y); ctx.rotate(b.r);
      ctx.globalAlpha = Math.max(0, 1 - k);
      ctx.fillStyle = b.c; ctx.fillRect(-b.w / 2, -b.h / 2, b.w, b.h);
      ctx.restore();
    }
    if (k < 1) requestAnimationFrame(step); else canvas.classList.add('hidden');
  })(t0);
}

let audioCtx = null;
function tone(notes) {
  try {
    audioCtx = audioCtx || new (window.AudioContext || window.webkitAudioContext)();
    if (audioCtx.state === 'suspended') audioCtx.resume();
    notes.forEach((f, i) => {
      const o = audioCtx.createOscillator();
      const g = audioCtx.createGain();
      const at = audioCtx.currentTime + i * 0.09;
      o.type = 'triangle';
      o.frequency.value = f;
      g.gain.setValueAtTime(0.0001, at);
      g.gain.exponentialRampToValueAtTime(0.25, at + 0.02);
      g.gain.exponentialRampToValueAtTime(0.0001, at + 0.28);
      o.connect(g).connect(audioCtx.destination);
      o.start(at);
      o.stop(at + 0.3);
    });
  } catch (_) { /* no audio: fine */ }
}

// Static texts in the chosen language.
function applyLanguage() {
  document.documentElement.lang = LANG;
  document.documentElement.dir = LANG === 'ar' ? 'rtl' : 'ltr';
  $('loading-text').textContent = t('loading');
  $('scan-hint').textContent = t('scan');
  $('held-badge').textContent = t('held');
  $('gesture-hint').textContent = t('hint');
  for (const [id, key, icon] of [['btn-sound', 'sound', '🔊'], ['btn-move', 'move', '🐾'], ['btn-hold', 'hold', '✋'], ['btn-reset', 'reset', '↺']]) {
    $(id).innerHTML = `<span>${icon}</span>${t(key)}`;
  }
}
applyLanguage();

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

// For each part ({at: [x,y,z]} as fractions of the posed bounding box), find
// the nearest vertex of the model. Following that vertex keeps the dot on the
// body while it animates (morph targets and skinning both apply).
function snapParts(model, box, defs) {
  const size = box.getSize(new THREE.Vector3());
  const meshes = [];
  model.traverse((o) => { if (o.isMesh && o.geometry.attributes.position) meshes.push(o); });
  const v = new THREE.Vector3();
  return defs.map((def) => {
    const target = new THREE.Vector3(...def.at).multiply(size).add(box.min);
    let best = { d: Infinity, mesh: null, index: 0 };
    for (const mesh of meshes) {
      const n = mesh.geometry.attributes.position.count;
      for (let i = 0; i < n; i++) {
        mesh.getVertexPosition(i, v).applyMatrix4(mesh.matrixWorld);
        const d = v.distanceToSquared(target);
        if (d < best.d) best = { d, mesh, index: i };
      }
    }
    return { def, mesh: best.mesh, index: best.index, world: new THREE.Vector3(), screen: { x: 0, y: 0 }, visible: false, el: null };
  });
}

// Device orientation -> camera orientation (as three.js DeviceOrientationControls).
const gyro = { q: new THREE.Quaternion(), ok: false };
{
  const euler = new THREE.Euler();
  const zee = new THREE.Vector3(0, 0, 1);
  const qScreen = new THREE.Quaternion();
  const qBack = new THREE.Quaternion(-Math.sqrt(0.5), 0, 0, Math.sqrt(0.5)); // camera looks out the back
  window.addEventListener('deviceorientation', (e) => {
    if (e.alpha === null || e.beta === null || e.gamma === null) return;
    const d = THREE.MathUtils.DEG2RAD;
    const orient = ((screen.orientation && screen.orientation.angle) || window.orientation || 0) * d;
    euler.set(e.beta * d, e.alpha * d, -e.gamma * d, 'YXZ');
    gyro.q.setFromEuler(euler).multiply(qBack).multiply(qScreen.setFromAxisAngle(zee, -orient));
    gyro.ok = state.gyro = true;
  });
}

async function askGyroPermission() {
  // iOS asks for permission, and only from a tap.
  const D = window.DeviceOrientationEvent;
  if (D && typeof D.requestPermission === 'function') {
    try { await D.requestPermission(); } catch (_) { /* denied: Hold still works without it */ }
  }
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

  // Holds the animal while "Hold" is on. Its matrix is the page pose at the
  // moment Hold was pressed, turned by how much the phone has turned since.
  const holdGroup = new THREE.Group();
  holdGroup.matrixAutoUpdate = false;
  holdGroup.visible = false;
  scene.add(holdGroup);
  const hold = { m0: new THREE.Matrix4(), q0: new THREE.Quaternion(), useGyro: false };

  const loader = new GLTFLoader();
  const shadowTexture = makeShadowTexture();
  let current = null; // the entry whose animal is on screen
  let lostTimer = null;

  // One entry per animal: its anchor, transform groups, animations, sound, parts.
  const entries = animals.map((a, i) => {
    const anchor = mindar.addAnchor(i);
    const root = new THREE.Group(); // user move (page X/Y)
    const tilt = new THREE.Group(); // user tip forward/back (about page X)
    const spin = new THREE.Group(); // user turn (about the page normal)
    const scaler = new THREE.Group(); // user resize
    const pop = new THREE.Group(); // tap bounce
    const orient = new THREE.Group(); // glTF Y-up -> page Z-up
    const turn = new THREE.Group(); // which way the model faces; also the twirl
    orient.rotation.x = Math.PI / 2;
    turn.rotation.y = THREE.MathUtils.degToRad(a.turn || 0);
    root.position.copy(HOME);
    anchor.group.add(root);
    root.add(tilt);
    tilt.add(spin);
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
      a, i, anchor, root, tilt, spin, scaler, pop, turn, audio,
      model: null, mixer: null, actions: [], actionIndex: 0, parts: [],
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
      entry.parts = snapParts(model, box, a.parts || []);
      for (const p of entry.parts) p.el = makePartDot(entry, p);
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
    $('aim').style.setProperty('--c', a.color);
    $('parts').style.setProperty('--c', a.color);
    $('name-en').textContent = a.en;
    $('name-fr').textContent = a.fr;
    $('name-ar').textContent = a.ar;
    $('fact').textContent = a['fact_' + LANG] || a.fact_en;
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

  function showPartsOf(entry) {
    for (const e of entries) for (const p of e.parts) p.el.classList.add('hidden');
    selection.part = null;
    selection.tapped = null;
    renderSelection();
    if (entry) for (const p of entry.parts) p.el.classList.toggle('hidden', !p.visible);
  }

  function onFound(entry) {
    if (state.held) return; // Hold ignores the pages until it is released
    clearTimeout(lostTimer);
    const isNew = current !== entry;
    current = entry;
    state.found = entry.a.id;
    state.foundCount++;
    showCard(entry.a);
    if (isNew) showPartsOf(entry);
    setPhase('found');
    if (isNew || performance.now() - entry.lastSoundAt > SOUND_REPEAT_MS) playSound(entry);
    ask('found', { id: entry.a.id }).then((r) => reward(r, t('newAnimal')));
    if (QUIZ) quizStart(entry);
  }

  function onLost(entry) {
    if (state.held) return;
    clearTimeout(lostTimer);
    lostTimer = setTimeout(() => {
      if (!state.held && current === entry && !entry.anchor.group.visible) {
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
    entry.tilt.rotation.x = 0;
    entry.spin.rotation.z = 0;
    entry.scaler.scale.setScalar(1);
  }

  // ---- Hold -------------------------------------------------------------------
  async function startHold() {
    if (!current || state.held) return;
    await askGyroPermission();
    const g = current.anchor.group;
    g.updateMatrixWorld(true);
    hold.m0.copy(g.matrixWorld);
    hold.q0.copy(gyro.q);
    hold.useGyro = gyro.ok;
    holdGroup.matrix.copy(hold.m0);
    holdGroup.matrixWorldNeedsUpdate = true;
    holdGroup.visible = true;
    holdGroup.add(current.root);
    clearTimeout(lostTimer);
    state.held = true;
    state.found = current.a.id;
    $('btn-hold').innerHTML = `<span>📖</span>${t('page')}`;
    setPhase('held');
    notifyApp('hold', { id: current.a.id, gyro: hold.useGyro });
  }

  function endHold() {
    if (!state.held) return;
    state.held = false;
    holdGroup.visible = false;
    $('btn-hold').innerHTML = `<span>✋</span>${t('hold')}`;
    if (current) current.anchor.group.add(current.root);
    // The camera may already see a page (this one or another): show it.
    const seen = entries.find((e) => e.anchor.group.visible);
    if (seen) { onFound(seen); return; }
    state.found = null;
    setPhase('scanning');
  }

  function updateHold() {
    if (!state.held || !hold.useGyro) return;
    // A point fixed in the room, seen from the turned phone:
    // p_now = q_now⁻¹ · q_hold · p_hold
    const turnSince = gyro.q.clone().invert().multiply(hold.q0);
    holdGroup.matrix.makeRotationFromQuaternion(turnSince).multiply(hold.m0);
    holdGroup.matrixWorldNeedsUpdate = true;
  }

  $('btn-sound').addEventListener('click', () => current && playSound(current));
  $('btn-move').addEventListener('click', () => current && nextMove(current));
  $('btn-hold').addEventListener('click', () => (state.held ? endHold() : startHold()));
  $('btn-reset').addEventListener('click', () => current && reset(current));

  // ---- Body parts -------------------------------------------------------------
  const selection = { part: null, tapped: null, tappedAt: 0 };
  const raycaster = new THREE.Raycaster();
  const ndc = new THREE.Vector2();
  const tmp = new THREE.Vector3();
  let lastOcclusion = 0;

  // Dots ignore touches so they never block turning or pinching; a tap near
  // one selects it (see endPointer).
  function makePartDot(entry, part) {
    const el = document.createElement('div');
    el.className = 'part-dot hidden';
    $('parts').append(el);
    return el;
  }

  function partNear(x, y) {
    if (!current) return null;
    let found = null, best = 30;
    for (const p of current.parts) {
      if (!p.visible) continue;
      const d = Math.hypot(p.screen.x - x, p.screen.y - y);
      if (d < best) { best = d; found = p; }
    }
    return found;
  }

  function renderSelection() {
    const label = $('part-label');
    const p = selection.part;
    for (const e of entries) for (const q of e.parts) q.el.classList.toggle('selected', q === p);
    $('aim').classList.toggle('on', !!p);
    if (!p) { label.classList.add('hidden'); return; }
    // In the quiz the names stay hidden until the right answer.
    if (QUIZ && quiz.reveal !== p) { label.classList.add('hidden'); return; }
    $('part-en').textContent = nameIn(p.def);
    $('part-other').textContent = otherNames(p.def);
    label.classList.toggle('right', QUIZ);
    label.classList.remove('hidden');
  }

  function updateParts(now) {
    const showing = state.phase === 'found' || state.phase === 'held';
    if (!current || !current.model || !showing) {
      if (selection.part) { selection.part = null; renderSelection(); }
      if (state.parts.visible.length) state.parts = { visible: [], selected: null };
      return;
    }
    const rect = renderer.domElement.getBoundingClientRect();
    const camPos = camera.getWorldPosition(new THREE.Vector3());
    const checkOcclusion = now - lastOcclusion > OCCLUSION_MS;
    if (checkOcclusion) lastOcclusion = now;

    for (const p of current.parts) {
      p.mesh.getVertexPosition(p.index, p.world).applyMatrix4(p.mesh.matrixWorld);
      tmp.copy(p.world).project(camera);
      p.screen.x = rect.left + ((tmp.x + 1) / 2) * rect.width;
      p.screen.y = rect.top + ((1 - tmp.y) / 2) * rect.height;
      const onScreen = tmp.z < 1 && p.screen.x > 0 && p.screen.x < innerWidth && p.screen.y > 0 && p.screen.y < innerHeight;
      if (checkOcclusion) {
        // Hidden behind the body? Cast a ray from the camera to the part.
        const dir = tmp.copy(p.world).sub(camPos);
        const dist = dir.length();
        raycaster.set(camPos, dir.normalize());
        raycaster.far = dist * 1.05;
        const hit = raycaster.intersectObject(current.model, true)[0];
        p.facing = !hit || hit.distance > dist * 0.97;
      }
      p.visible = onScreen && p.facing !== false;
      p.el.classList.toggle('hidden', !p.visible);
      p.el.style.transform = `translate(${p.screen.x}px, ${p.screen.y}px)`;
    }

    // Aimed part: the visible part nearest the aim target, if close enough.
    const ax = innerWidth / 2, ay = innerHeight * AIM_Y;
    const radius = Math.max(44, Math.min(innerWidth, innerHeight) * 0.13);
    let aimed = null, best = radius;
    for (const p of current.parts) {
      if (!p.visible) continue;
      const d = Math.hypot(p.screen.x - ax, p.screen.y - ay);
      if (d < best) { best = d; aimed = p; }
    }
    const tapped = selection.tapped && selection.tapped.visible && now - selection.tappedAt < TAP_SELECT_MS ? selection.tapped : null;
    const chosen = aimed || tapped;
    if (chosen !== selection.part) {
      selection.part = chosen;
      renderSelection();
      if (chosen && !QUIZ) {
        notifyApp('selected', { id: chosen.def.id });
        const part = chosen;
        ask('part', { animal: current.a.id, id: part.def.id }).then((r) => reward(r, `${t('newPart')} ${nameIn(part.def)}`));
      }
    }
    if (QUIZ) quizCheckAim(aimed, now);
    if (chosen) {
      $('part-label').style.transform = `translate(${chosen.screen.x}px, ${chosen.screen.y}px)`;
    }
    if (checkOcclusion) {
      state.parts = { visible: current.parts.filter((p) => p.visible).map((p) => p.def.id), selected: chosen ? chosen.def.id : null };
      state.quiz = { target: quiz.target ? quiz.target.def.id : null, correct: quiz.correct, done: quiz.done, animal: quiz.animal };
      state.partsAt = Object.fromEntries(current.parts.filter((p) => p.visible).map((p) => [p.def.id, [Math.round(p.screen.x), Math.round(p.screen.y)]]));
    }
  }

  // ---- Quiz (level 3) ---------------------------------------------------------
  const quiz = { animal: null, target: null, correct: 0, done: false, asked: new Set(), aimSince: null, busy: false, reveal: null };

  function quizStart(entry) {
    if (quiz.animal === entry.a.id) return;
    Object.assign(quiz, { animal: entry.a.id, target: null, correct: 0, done: false, asked: new Set(), aimSince: null, busy: false });
    quizNext();
  }

  function quizNext() {
    if (!current || !current.parts.length) { quiz.target = null; return; } // model still loading
    let pool = current.parts.filter((p) => !quiz.asked.has(p.def.id));
    if (!pool.length) { quiz.asked.clear(); pool = current.parts; }
    quiz.target = pool[Math.floor(Math.random() * pool.length)];
    quiz.asked.add(quiz.target.def.id);
    quiz.aimSince = null;
    banner(t('find', { p: partWithArticle(quiz.target.def) }), otherNames(quiz.target.def));
  }

  function quizCheckAim(aimed, now) {
    if (!quiz.target && !quiz.done && !quiz.busy && current && quiz.animal === current.a.id) quizNext();
    if (!quiz.target || quiz.busy) return;
    if (aimed === quiz.target) {
      if (quiz.aimSince === null) quiz.aimSince = now;
      else if (now - quiz.aimSince > QUIZ_DWELL_MS) quizRight(aimed);
    } else {
      quiz.aimSince = null;
    }
  }

  function quizAnswer(part) {
    if (!quiz.target || quiz.busy) return;
    if (part === quiz.target) { quizRight(part); return; }
    quiz.busy = true;
    tone([330, 262]);
    banner(t('wrong', { p: partWithArticle(part.def) }), '', 'wrong');
    setTimeout(() => {
      quiz.busy = false;
      if (quiz.target) banner(t('find', { p: partWithArticle(quiz.target.def) }), otherNames(quiz.target.def));
    }, 1600);
  }

  function quizRight(part) {
    quiz.busy = true;
    quiz.correct++;
    quiz.reveal = part;
    selection.part = part;
    renderSelection();
    tone([523, 659, 784, 1047]);
    confetti(70);
    banner(t('right', { p: partWithArticle(part.def) }), '', 'right');
    const animal = quiz.animal;
    ask('quiz', { animal, part: part.def.id }).then((r) => reward(r, null));
    setTimeout(() => {
      quiz.busy = false;
      quiz.reveal = null;
      renderSelection();
      if (quiz.correct >= QUIZ_GOAL) {
        quiz.done = true;
        quiz.target = null;
        banner(t('quizDone'), '', 'right');
        confetti(160);
      } else {
        quizNext();
      }
    }, 1800);
  }

  function banner(text, sub = '', mood = '') {
    $('quiz-text').textContent = text;
    $('quiz-sub').textContent = sub;
    $('quiz').className = mood;
    $('quiz').classList.toggle('hidden', !(state.phase === 'found' || state.phase === 'held'));
  }

  // ---- Rewards ------------------------------------------------------------------
  // The app answers with { new, stars, levelUp }.
  function reward(r, newText) {
    if (!r) return;
    if (r.new && newText) toast(newText);
    if (r.levelUp) {
      celebrate(r.levelUp >= 4 ? t('allDone') : t('levelUp', { n: r.levelUp }));
    }
  }

  // ---- Gestures -----------------------------------------------------------
  const container = $('ar');
  const pointers = new Map();
  const plane = new THREE.Plane();
  let gesture = null;

  function toNdc(x, y) {
    const r = renderer.domElement.getBoundingClientRect();
    ndc.set(((x - r.left) / r.width) * 2 - 1, -((y - r.top) / r.height) * 2 + 1);
    raycaster.far = Infinity;
    raycaster.setFromCamera(ndc, camera);
  }

  // Where a screen point lands on the page (or the held page), in page coordinates.
  function pageHit(x, y) {
    if (!current) return null;
    toNdc(x, y);
    const g = current.root.parent;
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
      gesture = { kind: 'turn', x0: pts[0].x, y0: pts[0].y, rot0: current.spin.rotation.z, tilt0: current.tilt.rotation.x };
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
      // left/right turns it; up/down tips it to show its back or belly
      current.spin.rotation.z = gesture.rot0 + (pts[0].x - gesture.x0) * 0.012;
      current.tilt.rotation.x = THREE.MathUtils.clamp(gesture.tilt0 + (pts[0].y - gesture.y0) * 0.01, -1.4, 1.4);
    } else if (gesture.kind === 'pinch' && pts.length >= 2) {
      const [p, q] = pts;
      const d = Math.hypot(p.x - q.x, p.y - q.y);
      current.scaler.scale.setScalar(THREE.MathUtils.clamp(gesture.scale0 * d / gesture.d0, 0.35, MAX_SCALE));
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
    if (wasSingle && moved < 10 && performance.now() - p.t0 < 350) {
      const part = partNear(p.x, p.y);
      if (part) {
        selection.tapped = part;
        selection.tappedAt = performance.now();
        if (QUIZ) quizAnswer(part);
      } else if (hitsAnimal(p.x, p.y)) {
        playSound(current);
      }
    }
    beginGesture(); // re-baseline with the fingers still down
  };
  container.addEventListener('pointerup', endPointer);
  container.addEventListener('pointercancel', endPointer);
  container.addEventListener('wheel', (e) => {
    if (!current) return;
    e.preventDefault();
    const s = current.scaler.scale.x * Math.exp(-e.deltaY * 0.001);
    current.scaler.scale.setScalar(THREE.MathUtils.clamp(s, 0.35, MAX_SCALE));
  }, { passive: false });

  // ---- Render loop ----------------------------------------------------------
  const clock = new THREE.Clock();
  let fpsFrames = 0, fpsT = performance.now(), fps = 0;
  function frame() {
    const dt = Math.min(clock.getDelta(), 0.1);
    const now = performance.now();
    updateHold();
    for (const e of entries) {
      const shown = e.anchor.group.visible || (state.held && e === current);
      if (!shown) continue;
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
    updateParts(now);
    state.frames++;
    if (current) {
      state.transform = {
        turn: +current.spin.rotation.z.toFixed(3),
        tilt: +current.tilt.rotation.x.toFixed(3),
        scale: +current.scaler.scale.x.toFixed(3),
        x: +current.root.position.x.toFixed(3),
        y: +current.root.position.y.toFixed(3),
      };
    }
    if (DEBUG) {
      fpsFrames++;
      if (now - fpsT > 500) {
        fps = Math.round((fpsFrames * 1000) / (now - fpsT));
        fpsFrames = 0; fpsT = now;
        $('debug').textContent = `${state.phase} ${state.found || '-'}\n${fps} fps · models ${state.modelsLoaded}/${entries.length}`
          + `\nparts ${state.parts.visible.length} · ${state.parts.selected || '-'}${state.gyro ? ' · gyro' : ''}`;
      }
    }
  }

  async function startAr() {
    setPhase('loading');
    await mindar.start();
    renderer.setAnimationLoop(frame);
    setPhase(state.held ? 'held' : 'scanning');
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
    showError(name === 'NotAllowedError' ? t('cameraOff') : t('cameraFail'));
  }
}

main().catch((err) => {
  console.error(err);
  showError(t('loadFail') + (err && err.message ? err.message : err));
});
