// Generates the Pillie "Unlock Success" payoff Lottie — a calm, premium burst:
// two expanding release rings (coral, then green), a soft central flash, and a
// ring of 4-point sparkles popping outward. Transparent for overlay use in-app.
import fs from 'node:fs'
import path from 'node:path'

const W = 512, H = 512, FR = 60, OP = 66
const CX = 256, CY = 256
const coral = [1.0, 0.7176, 0.698]
const green = [0.4902, 0.6392, 0.4824]
const white = [1, 1, 1]

// Cubic-bezier easing presets for keyframe interpolation.
const eOut = { i: { x: [0.16], y: [1] }, o: { x: [0.3], y: [0] } }
const eInOut = { i: { x: [0.45], y: [1] }, o: { x: [0.55], y: [0] } }

const animO = (kfs) => ({ a: 1, k: kfs })
const stat = (k) => ({ a: 0, k })
const kf = (t, s, ease) => (ease ? { t, s, i: ease.i, o: ease.o } : { t, s })

// Transform block shared by shape groups (identity).
const trIdentity = () => ({
  ty: 'tr', p: stat([0, 0]), a: stat([0, 0]),
  s: stat([100, 100]), r: stat(0), o: stat(100),
})

function baseLayer(nm, ip, op) {
  return {
    ty: 4, nm, ip, op: OP, st: 0, sr: 1, bm: 0,
    ks: { o: stat(100), r: stat(0), p: stat([CX, CY, 0]), a: stat([0, 0, 0]), s: stat([100, 100, 100]) },
    shapes: [],
  }
}

// A stroked ring that scales up while fading out — a "release" pulse.
function ring(nm, color, strokeW, startF, peakO, endF, fromS, toS) {
  const l = baseLayer(nm, startF, endF)
  l.ks.o = animO([kf(startF, [0], eOut), kf(startF + 4, [peakO], eInOut), kf(endF, [0])])
  l.ks.s = animO([kf(startF, [fromS, fromS, 100], eOut), kf(endF, [toS, toS, 100])])
  l.shapes = [{
    ty: 'gr', nm: `${nm}-g`, it: [
      { ty: 'el', p: stat([0, 0]), s: stat([170, 170]) },
      { ty: 'st', c: stat([...color, 1]), o: stat(100), w: stat(strokeW), lc: 2, lj: 1 },
      trIdentity(),
    ],
  }]
  return l
}

// A soft central flash disc.
function flash(nm, color, peakO) {
  const l = baseLayer(nm, 0, 30)
  l.ks.o = animO([kf(0, [0], eOut), kf(8, [peakO], eInOut), kf(30, [0])])
  l.ks.s = animO([kf(0, [40, 40, 100], eOut), kf(30, [125, 125, 100])])
  l.shapes = [{
    ty: 'gr', nm: `${nm}-g`, it: [
      { ty: 'el', p: stat([0, 0]), s: stat([150, 150]) },
      { ty: 'fl', c: stat([...color, 1]), o: stat(100) },
      trIdentity(),
    ],
  }]
  return l
}

// A 4-point sparkle that pops, drifts outward, and fades.
function sparkle(nm, angleDeg, dist, size, color, startF) {
  const rad = (angleDeg * Math.PI) / 180
  const ex = CX + Math.cos(rad) * dist
  const ey = CY + Math.sin(rad) * dist
  const near = [CX + Math.cos(rad) * dist * 0.4, CY + Math.sin(rad) * dist * 0.4, 0]
  const far = [ex, ey, 0]
  const endF = startF + 30
  const l = baseLayer(nm, startF, endF)
  l.ks.p = animO([kf(startF, near, eOut), kf(endF, far)])
  l.ks.o = animO([kf(startF, [0], eOut), kf(startF + 6, [100], eInOut), kf(endF, [0])])
  l.ks.s = animO([kf(startF, [0, 0, 100], eOut), kf(startF + 8, [120, 120, 100], eInOut), kf(endF, [60, 60, 100])])
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

// Background layer (kept transparent for in-app overlay) — exposes the bgColor slot.
function background() {
  const l = baseLayer('bg', 0, OP)
  l.ks.o = stat(0) // invisible in-app; toggle via the player to preview on a fill
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
  [18, 175, 17, coral, 10], [72, 200, 13, green, 14], [128, 165, 18, white, 11],
  [186, 195, 14, coral, 15], [232, 170, 16, green, 12], [300, 198, 12, coral, 16],
  [340, 160, 15, white, 13],
]

// `APP=1` strips the player-only bgColor slot + invisible bg layer, which
// lottie-ios's parser can reject (slot-only fill with no default value).
const appBuild = process.env.APP === '1'

const layers = [
  ...sparkleSpecs.map((s, i) => sparkle(`sparkle-${i + 1}`, ...s)),
  flash('flash', coral, 20),
  ring('ring-green', green, 6, 8, 85, 56, 14, 230),
  ring('ring-coral', coral, 8, 0, 95, 44, 22, 190),
  ...(appBuild ? [] : [background()]),
]

const doc = {
  v: '5.7.0', fr: FR, ip: 0, op: OP, w: W, h: H, nm: 'Pillie Unlock Success', ddd: 0,
  assets: [],
  ...(appBuild ? {} : { slots: { bgColor: { p: { a: 0, k: [1, 1, 1, 1] } } } }),
  layers,
}

const outDir = path.resolve('public/projects/main-project/scene-1')
fs.mkdirSync(outDir, { recursive: true })
fs.writeFileSync(path.join(outDir, 'lottie.json'), JSON.stringify(doc, null, 2))
fs.writeFileSync(path.join(outDir, 'controls.json'), JSON.stringify({ controls: [{ sid: 'bgColor', label: 'Background color' }] }, null, 2))
console.log('wrote', path.join(outDir, 'lottie.json'), `(${layers.length} layers, op=${OP})`)
