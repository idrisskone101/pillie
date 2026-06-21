// Generates the Pillie "Plan Reveal" hero Lottie for the Personalized Diagnosis
// reveal (issue #78 follow-up, matching Superdesign draft 5fb4ec60). Two-phase
// moment: an ANALYZING scan (rotating sweep + radar rings + the distraction tiles
// flying in), then it resolves into a VERIFIED, on-brand shield — a soft rounded
// crest with a coral->amber gradient fill and a cream "sticker" outline that draws
// on, a thick rounded check, a glow halo, and a sparkle burst. Transparent for
// overlay use in-app. Palette + soft rounded forms echo the Pillie app mark.
//
// Authoring/preview (diffusionstudio/lottie player, with the bgColor slot):
//   node Pillie/Tools/Lottie/gen-plan-reveal.mjs
// In-app asset (lottie-ios; strips the player-only bgColor slot + bg layer):
//   APP=1 node Pillie/Tools/Lottie/gen-plan-reveal.mjs   -> Pillie/Pillie/Resources/plan_reveal.json
import fs from 'node:fs'
import path from 'node:path'

const W = 512, H = 512, FR = 60, OP = 190
const CX = 256, CY = 252

// Brand palette (PillieTheme).
const coral = [1.0, 0.7176, 0.698]      // #FFB7B2
const amber = [0.909, 0.659, 0.486]     // #E8A87C  (legacy accent, no longer on the shield)
const shieldTop = [0.2275, 0.2078, 0.1922]    // #3A3531  (shield top — brand dark, matches the medallion)
const shieldBottom = [0.1608, 0.1451, 0.1412] // #292524  (shield bottom — brand dark)
const coralLight = [1.0, 0.941, 0.929]  // #FFF0ED
const cream = [1.0, 0.968, 0.957]
const white = [1, 1, 1]
const green = [0.4902, 0.6392, 0.4824]  // #7DA37B verifiedGreen
// App-tile palette — the EXACT pale brand tints used by the plan's app-lock card
// (PillieTheme.coralLight / .lavender / .sage), with the textMuted glyph color, so
// the loading tiles read as the same little app cards that appear in the plan.
const lavender = [0.9373, 0.9294, 0.9569] // #EFEDF4
const sage = [0.9098, 0.9373, 0.9098]     // #E8EFE8
const textMuted = [0.4706, 0.4431, 0.4235] // #78716C

const eOut = { i: { x: [0.16], y: [1] }, o: { x: [0.3], y: [0] } }
const eInOut = { i: { x: [0.45], y: [1] }, o: { x: [0.55], y: [0] } }

const animO = (kfs) => ({ a: 1, k: kfs })
const stat = (k) => ({ a: 0, k })
const kf = (t, s, ease) => (ease ? { t, s, i: ease.i, o: ease.o } : { t, s })
const trIdentity = () => ({
  ty: 'tr', p: stat([0, 0]), a: stat([0, 0]),
  s: stat([100, 100]), r: stat(0), o: stat(100),
})

function baseLayer(nm, ip) {
  return {
    ty: 4, nm, ip, op: OP, st: 0, sr: 1, bm: 0,
    ks: { o: stat(100), r: stat(0), p: stat([CX, CY, 0]), a: stat([0, 0, 0]), s: stat([100, 100, 100]) },
    shapes: [],
  }
}

// ---- Phase 1: analyzing (0 - ANALYZE_END) ---------------------------------

const ANALYZE_END = 86

function radar(nm, startF, color) {
  const a = startF, b = startF + 40
  const l = baseLayer(nm, a)
  l.op = b
  l.ks.o = animO([kf(a, [0], eOut), kf(a + 6, [55], eInOut), kf(b, [0])])
  l.ks.s = animO([kf(a, [26, 26, 100], eOut), kf(b, [190, 190, 100])])
  l.shapes = [{
    ty: 'gr', nm: `${nm}-g`, it: [
      { ty: 'el', p: stat([0, 0]), s: stat([200, 200]) },
      { ty: 'st', c: stat([...color, 1]), o: stat(100), w: stat(5), lc: 2, lj: 1 },
      trIdentity(),
    ],
  }]
  return l
}

function scanSweep(startF, endF) {
  const l = baseLayer('scan-sweep', startF)
  l.op = endF + 8
  l.ks.r = animO([kf(startF, [0], eOut), kf(endF, [720], eInOut)])
  l.ks.o = animO([kf(startF, [0], eOut), kf(startF + 8, [85], eInOut), kf(endF - 6, [85], eInOut), kf(endF + 8, [0])])
  l.shapes = [{
    ty: 'gr', nm: 'scan-sweep-g', it: [
      { ty: 'el', p: stat([0, 0]), s: stat([150, 150]) },
      { ty: 'tm', nm: 'arc', s: stat(0), e: stat(24), o: stat(0), m: 1 },
      { ty: 'st', c: stat([...coral, 1]), o: stat(100), w: stat(7), lc: 2, lj: 1 },
      trIdentity(),
    ],
  }]
  return l
}

function core(endF) {
  const l = baseLayer('core', 0)
  l.op = endF + 8
  l.ks.o = animO([kf(0, [0], eOut), kf(10, [100], eInOut), kf(endF - 8, [100], eInOut), kf(endF + 6, [0])])
  l.ks.s = animO([
    kf(0, [70, 70, 100], eOut), kf(30, [104, 104, 100], eInOut),
    kf(58, [80, 80, 100], eInOut), kf(endF, [92, 92, 100]),
  ])
  l.shapes = [{
    ty: 'gr', nm: 'core-g', it: [
      { ty: 'el', p: stat([0, 0]), s: stat([46, 46]) },
      { ty: 'fl', c: stat([...coral, 1]), o: stat(100) },
      trIdentity(),
    ],
  }]
  return l
}

// A small rounded "app tile" that flies in, settles in a row, then is absorbed
// (shrinks + fades into the center) as the shield seals over it.
function tile(nm, startF, from, settle, color) {
  const l = baseLayer(nm, startF)
  l.op = 116
  const arriveF = startF + 26
  l.ks.p = animO([
    kf(startF, [from[0], from[1], 0], eOut),
    kf(arriveF, [settle[0], settle[1], 0], eInOut),
    kf(84, [settle[0], settle[1], 0], eInOut),
    kf(108, [CX, CY - 6, 0]),
  ])
  l.ks.s = animO([
    kf(startF, [0, 0, 100], eOut),
    kf(startF + 18, [108, 108, 100], eInOut),
    kf(arriveF, [100, 100, 100], eInOut),
    kf(84, [100, 100, 100], eInOut),
    kf(108, [26, 26, 100]),
  ])
  l.ks.o = animO([
    kf(startF, [0], eOut), kf(startF + 12, [100], eInOut),
    kf(92, [100], eInOut), kf(108, [0]),
  ])
  l.ks.r = animO([kf(startF, [-12], eOut), kf(arriveF, [0])])
  l.shapes = [
    {
      // 2x2 rounded grid (matches the card's `square.grid.2x2.fill`), in textMuted.
      ty: 'gr', nm: `${nm}-glyph`, it: [
        { ty: 'rc', p: stat([-7, -7]), s: stat([11, 11]), r: stat(3) },
        { ty: 'rc', p: stat([7, -7]), s: stat([11, 11]), r: stat(3) },
        { ty: 'rc', p: stat([-7, 7]), s: stat([11, 11]), r: stat(3) },
        { ty: 'rc', p: stat([7, 7]), s: stat([11, 11]), r: stat(3) },
        { ty: 'fl', c: stat([...textMuted, 1]), o: stat(55) },
        trIdentity(),
      ],
    },
    {
      // Pale tinted card body with a crisp white border — the same little app tile
      // shown in the plan's app-lock card, just elevated for the reveal.
      ty: 'gr', nm: `${nm}-body`, it: [
        { ty: 'rc', p: stat([0, 0]), s: stat([64, 64]), r: stat(18) },
        { ty: 'st', c: stat([...white, 1]), o: stat(100), w: stat(4), lc: 2, lj: 1 },
        { ty: 'fl', c: stat([...color, 1]), o: stat(100) },
        trIdentity(),
      ],
    },
  ]
  return l
}

// ---- Phase 2: verified shield ---------------------------------------------

// The crest shield — IDENTICAL silhouette to the in-app medallion (CrestShield),
// so the reveal's shield and the verified plan's medallion read as one logo.
const shieldPath = {
  c: true,
  v: [[0, -74], [62, -50], [62, 0], [0, 74], [-62, 0], [-62, -50]],
  i: [[0, 0], [0, 0], [0, 0], [34, -9], [0, 40], [0, 0]],
  o: [[0, 0], [0, 0], [0, 40], [-34, -9], [0, 0], [0, 0]],
}

const drawOn = (startF, endF) => ({
  ty: 'tm', nm: 'draw',
  s: stat(0),
  e: animO([kf(startF, [0], eOut), kf(endF, [100], eInOut)]),
  o: stat(0), m: 1,
})

// The #FFC9A8 -> #E8A87C gradient shield body, popping into place (no outline — the
// medallion shield is pure gradient; the white circle behind it is the SwiftUI side).
function shieldFill(startF) {
  const l = baseLayer('shield-fill', startF)
  l.ks.o = animO([kf(startF, [0], eOut), kf(startF + 12, [100], eInOut)])
  l.ks.s = animO([
    kf(startF, [60, 60, 100], eOut),
    kf(startF + 16, [110, 110, 100], eInOut),
    kf(startF + 30, [100, 100, 100]),
  ])
  l.shapes = [{
    ty: 'gr', nm: 'shield-fill-g', it: [
      { ty: 'sh', nm: 'shield', ks: stat(shieldPath) },
      {
        ty: 'gf', nm: 'grad', o: stat(100), r: 1, bm: 0,
        g: { p: 2, k: stat([0, ...shieldTop, 1, ...shieldBottom]) },
        s: stat([0, -74]), e: stat([0, 74]), t: 1,
      },
      trIdentity(),
    ],
  }]
  return l
}

// A soft pale glow behind the shield.
function halo(startF) {
  const l = baseLayer('halo', startF)
  l.ks.o = animO([kf(startF, [0], eOut), kf(startF + 22, [30], eInOut)])
  l.ks.s = animO([kf(startF, [70, 70, 100], eOut), kf(startF + 26, [100, 100, 100])])
  l.shapes = [{
    ty: 'gr', nm: 'halo-g', it: [
      { ty: 'el', p: stat([0, 4]), s: stat([300, 300]) },
      { ty: 'fl', c: stat([...coralLight, 1]), o: stat(100) },
      trIdentity(),
    ],
  }]
  return l
}

// The confirming checkmark drawing on inside the shield (white, thick, rounded).
function checkmark(startF, endF) {
  const l = baseLayer('check', startF)
  const checkPath = {
    c: false,
    v: [[-26, 2], [-8, 20], [28, -20]],
    i: [[0, 0], [0, 0], [0, 0]],
    o: [[0, 0], [0, 0], [0, 0]],
  }
  l.ks.s = animO([kf(startF, [80, 80, 100], eOut), kf(endF, [108, 108, 100], eInOut), kf(endF + 10, [100, 100, 100])])
  l.shapes = [{
    ty: 'gr', nm: 'check-g', it: [
      { ty: 'sh', nm: 'check', ks: stat(checkPath) },
      drawOn(startF, endF),
      { ty: 'st', c: stat([...coral, 1]), o: stat(100), w: stat(13), lc: 2, lj: 2 },
      trIdentity(),
    ],
  }]
  return l
}

function ring(nm, color, strokeW, startF, peakO, endF, fromS, toS) {
  const l = baseLayer(nm, startF)
  l.op = endF
  l.ks.o = animO([kf(startF, [0], eOut), kf(startF + 4, [peakO], eInOut), kf(endF, [0])])
  l.ks.s = animO([kf(startF, [fromS, fromS, 100], eOut), kf(endF, [toS, toS, 100])])
  l.shapes = [{
    ty: 'gr', nm: `${nm}-g`, it: [
      { ty: 'el', p: stat([0, 0]), s: stat([200, 200]) },
      { ty: 'st', c: stat([...color, 1]), o: stat(100), w: stat(strokeW), lc: 2, lj: 1 },
      trIdentity(),
    ],
  }]
  return l
}

function sparkle(nm, angleDeg, dist, size, color, startF) {
  const rad = (angleDeg * Math.PI) / 180
  const near = [CX + Math.cos(rad) * dist * 0.45, CY + Math.sin(rad) * dist * 0.45, 0]
  const far = [CX + Math.cos(rad) * dist, CY + Math.sin(rad) * dist, 0]
  const endF = startF + 34
  const l = baseLayer(nm, startF)
  l.op = endF
  l.ks.p = animO([kf(startF, near, eOut), kf(endF, far)])
  l.ks.o = animO([kf(startF, [0], eOut), kf(startF + 7, [100], eInOut), kf(endF, [0])])
  l.ks.s = animO([kf(startF, [0, 0, 100], eOut), kf(startF + 9, [120, 120, 100], eInOut), kf(endF, [60, 60, 100])])
  l.ks.r = animO([kf(startF, [0], eOut), kf(endF, [55])])
  l.shapes = [{
    ty: 'gr', nm: `${nm}-g`, it: [
      { ty: 'sr', sy: 1, pt: stat(4), p: stat([0, 0]), r: stat(0), or: stat(size), ir: stat(size * 0.38), os: stat(0), is: stat(0) },
      { ty: 'fl', c: stat([...color, 1]), o: stat(100) },
      trIdentity(),
    ],
  }]
  return l
}

function background() {
  const l = baseLayer('bg', 0)
  l.ks.o = stat(0)
  l.shapes = [{
    ty: 'gr', nm: 'bg-g', it: [
      { ty: 'rc', p: stat([CX, CY]), s: stat([W, H]), r: stat(0) },
      { ty: 'fl', c: { sid: 'bgColor' }, o: stat(100) },
      trIdentity(),
    ],
  }]
  return l
}

const sparkleSpecs = [
  [22, 196, 17, coral, 126], [74, 214, 13, coral, 132], [128, 188, 18, white, 128],
  [200, 208, 14, coral, 134], [248, 192, 16, coral, 130], [308, 208, 13, coral, 136],
  [338, 182, 15, white, 131],
]

const appBuild = process.env.APP === '1'

const layers = [
  ...sparkleSpecs.map((s, i) => sparkle(`sparkle-${i + 1}`, ...s)),
  ring('seal-ring', coral, 5, 116, 60, 158, 70, 260),
  checkmark(116, 144),
  shieldFill(86),
  halo(94),
  tile('tile-1', 16, [-70, 320], [200, 256], coralLight),
  tile('tile-2', 28, [256, -70], [256, 242], lavender),
  tile('tile-3', 40, [582, 320], [312, 256], sage),
  scanSweep(0, ANALYZE_END),
  radar('radar-4', 66, coral),
  radar('radar-3', 44, coral),
  radar('radar-2', 22, coral),
  radar('radar-1', 2, coral),
  core(ANALYZE_END),
  ...(appBuild ? [] : [background()]),
]

const doc = {
  v: '5.7.0', fr: FR, ip: 0, op: OP, w: W, h: H, nm: 'Pillie Plan Reveal', ddd: 0,
  assets: [],
  ...(appBuild ? {} : { slots: { bgColor: { p: { a: 0, k: [1, 1, 1, 1] } } } }),
  layers,
}

let outPath
if (appBuild) {
  outPath = path.resolve('Pillie/Pillie/Resources/plan_reveal.json')
} else {
  outPath = '/tmp/pillie-lottie-player/public/projects/main-project/scene-1/lottie.json'
}
fs.mkdirSync(path.dirname(outPath), { recursive: true })
fs.writeFileSync(outPath, JSON.stringify(doc, null, 2))
if (!appBuild) {
  fs.writeFileSync(path.join(path.dirname(outPath), 'controls.json'), JSON.stringify({ controls: [{ sid: 'bgColor', label: 'Background color' }] }, null, 2))
}
console.log('wrote', outPath, `(${layers.length} layers, op=${OP}, app=${appBuild})`)
