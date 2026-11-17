# Animal Book AR (MVP)

A phone app for children: point the camera at an animal page in the book and a
3D animated animal appears standing on the page. It plays the animal's sound,
shows its name in English, French and Arabic with a fun fact, and the child can
turn it, resize it and move it with their fingers.

Five animals: horse, fox, flamingo, parrot, stork.

## How it works

```
Flutter app (Android + iOS)
 ├─ Home screen: camera button, how-to, the 5 book pages
 └─ AR screen: WebView ──> local server on 127.0.0.1 (lib/ar_server.dart)
                               └─ assets/ar/index.html
                                    ├─ MindAR: finds the page in the camera image (image tracking)
                                    ├─ three.js: draws and animates the 3D animal on the page
                                    └─ gestures, sound, name card
```

Why a web AR engine inside Flutter rather than ARCore/ARKit:

- **It works on every phone with a camera.** ARCore only runs on certified
  phones, and many low-cost Android phones are not on the list.
- **One AR code base** for Android and iPhone.
- **It can be tested on a Mac** with a fake camera (see Tests). ARCore can't run
  in the emulator on Apple-silicon Macs, and ARKit doesn't run in the Simulator.

The trade-off: tracking is a bit less steady than native ARKit/ARCore, and the
animal stays on the page (it can't walk off onto the table). For a book, that's
the right behaviour.

## Folders

| Path | What |
|---|---|
| `app/` | Flutter app (`com.synapexa.animal_book_ar`) |
| `app/assets/ar/` | AR page: `index.html`, `ar.js`, `ar.css`, `animals.json`, `targets.mind`, models, sounds, page JPEGs, vendored MindAR + three.js |
| `app/assets/ar/animals.json` | **The list of animals.** Names, facts, model, sound, colour, size. Read by the app, the AR page and the page generator |
| `book/animal-book.pdf` | Printable book, A4, one animal per page |
| `book/pages/*.png` | The same pages as images (also what the tracker learns) |
| `tool/` | Page generator, target compiler, end-to-end AR test, source photos |
| `CREDITS.md` | Authors and licences of the photos, sounds and models |

## Try it

1. Print `book/animal-book.pdf` (or open a page on a laptop screen, or tap a page
   in the app on a second phone).
2. Run the app on a phone:

```bash
cd app && flutter run
```

3. Tap **Open the AR camera**, allow the camera, point it at a page so the whole
   page is in view. Hold the phone at an angle, like reading, to see the animal
   stand up.

Gestures: tap the animal to hear it · one finger left/right to turn it · two
fingers to pinch (resize) and drag (move on the page) · **Move** changes the
animation (the fox walks and runs, the others twirl) · **Reset**.

## Add or change an animal

1. Add a `.glb` model to `app/assets/ar/models/`, a short `.m4a` sound to
   `app/assets/ar/sounds/`, and a photo to `tool/photos/<id>.jpg`.
2. Add an entry to `app/assets/ar/animals.json` (and photo credit to `tool/credits.json`).
3. Rebuild the pages and the tracking file:

```bash
python3 tool/make_pages.py
```

```bash
python3 tool/compile_targets.py
```

`size` is the animal's length as a share of the page width, `lift` raises
flying animals above the page, `turn` is the facing angle in degrees.

Any printed page can become a target. To use an existing book instead of these
pages, put photos of its pages in `book/pages/<id>.png` and run only
`compile_targets.py`. Pages with lots of detail track best; plain or repetitive
pages track badly.

## Tests

```bash
node tool/test_web_ar.mjs
```

This runs the AR page in headless Chrome with a fake camera playing a video of
the five pages on a desk. It checks that every page is found in order and lost
when it leaves the view, a sound plays for each, all models load, dragging
turns and the wheel resizes. Screenshots go to `tool/test-output/`. Needs Chrome
and ffmpeg.

```bash
cd app && flutter test
```

Covers the animal list, the home screen and the local server (content types,
byte ranges, 404s).

## What has been verified (2026-11-16)

- **Page tracking, 3D, sound, gestures:** `tool/test_web_ar.mjs` passes in
  headless Chrome. All 5 pages are found and lost in order, and each animal's sound plays.
- **Android emulator (API 35, WebView 124):** the home screen, camera permission,
  full-screen camera feed in the AR screen, all 5 models loading, pausing the
  camera in the background and resuming, and the back button. The emulator's
  virtual room shows no posters, so finding a page was not shown there.
- **iPhone Simulator (iOS 18.1):** the app builds and runs, the AR page loads in
  WebKit, the Simulator's test camera feed shows, and the page reports "ready".

- **Real phone, Redmi Note 14 Pro (Android 15, WebView 157), 2026-11-17:** the
  horse page shown on a laptop screen was found within seconds. The horse
  appeared galloping on the page, the card showed, and the sound played. About 20 fps while
  scanning, 59 fps while tracking.

## Known limits / next steps

- Not yet tried: a printed page, the other four pages on the phone, an iPhone.
- The test emulator is `AnimalAR_API_35` (camera = virtual scene). To debug the
  WebView, run `adb forward tcp:9333 localabstract:webview_devtools_remote_<pid>`
  and open `chrome://inspect`.
- The horse and birds are prototype models from the three.js examples (see
  CREDITS.md). Replace them before publishing.
- The app UI is English; the animal names and facts are in English, French and Arabic.
  Ideas: speak the name aloud, a quiz mode, more animals, an Arabic UI.
