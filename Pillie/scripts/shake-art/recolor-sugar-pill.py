#!/usr/bin/env python3
"""Make the sugar pill shake frames from the hormone pill frames.

Recolors only the pink pill, keeping every pixel's shading and position, so the
green frames stay registered with ShakeLayerBlisterEmpty. The target colour is
sampled from PackTilePlacebo, the sugar pill the pack card already shows.

Run from the repo root: python3 Pillie/scripts/shake-art/recolor-sugar-pill.py
"""

from pathlib import Path

from PIL import Image, ImageFilter

ASSETS = Path("Pillie/Pillie/Assets.xcassets")
LAYERS = ASSETS / "StopMotionLayers"
FRAMES = {
    "ShakeLayerBlisterSealed.imageset/ShakeLayerBlisterSealed.jpg": "ShakeLayerSugarBlisterSealed",
    "ShakeLayerBlisterDented.imageset/ShakeLayerBlisterDented.jpg": "ShakeLayerSugarBlisterDented",
    "ShakeLayerPill.imageset/ShakeLayerPill.png": "ShakeLayerSugarPill",
}


def ycbcr(rgb):
    r, g, b = rgb
    y = 0.299 * r + 0.587 * g + 0.114 * b
    return y, b - y, r - y


def pill_pixels(image, test):
    return [p for p in image.getdata() if test(p)]


def mean(values):
    values = list(values)
    return sum(values) / len(values)


def target_chroma():
    placebo = Image.open(ASSETS / "PackTiles/PackTilePlacebo.imageset/PackTilePlacebo.jpg").convert("RGB")
    sage = pill_pixels(placebo, lambda p: p[1] - p[2] > 12 and p[1] - p[0] > 4)
    active = Image.open(ASSETS / "PackTiles/PackTileActive.imageset/PackTileActive.jpg").convert("RGB")
    pink = pill_pixels(active, lambda p: p[0] - p[2] > 40)
    sage_ycc = [ycbcr(p) for p in sage]
    pink_ycc = [ycbcr(p) for p in pink]
    lift = mean(y for y, _, _ in sage_ycc) / mean(y for y, _, _ in pink_ycc)
    return mean(cb for _, cb, _ in sage_ycc), mean(cr for _, _, cr in sage_ycc), lift


def pink_mask(rgb_image):
    # Soft ramp on "how pink", starting low enough to catch the pill's pink bounce
    # light on the foil (the foil itself is neutral, r close to b).
    r, _, b = rgb_image.split()
    mask = Image.new("L", rgb_image.size)
    mask.putdata([max(0, min(255, int((pr - pb - 5) * 255 / 20))) for pr, pb in zip(r.getdata(), b.getdata())])
    return mask.filter(ImageFilter.GaussianBlur(1.5))


def recolor(source, target_cb, target_cr, lift):
    rgba = source.convert("RGBA")
    rgb = rgba.convert("RGB")
    mask = pink_mask(rgb)
    pink = pill_pixels(rgb, lambda p: p[0] - p[2] > 40)
    src_strength = mean(abs(ycbcr(p)[2]) + abs(ycbcr(p)[1]) for p in pink)
    out = []
    for (r, g, b, a), m in zip(rgba.getdata(), mask.getdata()):
        if m == 0:
            out.append((r, g, b, a))
            continue
        y, cb, cr = ycbcr((r, g, b))
        strength = (abs(cb) + abs(cr)) / src_strength
        ny = min(255.0, y * lift)
        ncb, ncr = target_cb * strength, target_cr * strength
        nr = ny + ncr
        nb = ny + ncb
        ng = (ny - 0.299 * nr - 0.114 * nb) / 0.587
        t = m / 255
        mix = lambda old, new: int(round(max(0, min(255, old * (1 - t) + new * t))))
        out.append((mix(r, nr), mix(g, ng), mix(b, nb), a))
    result = Image.new("RGBA", rgba.size)
    result.putdata(out)
    return result


def write_imageset(image, name, suffix):
    folder = LAYERS / f"{name}.imageset"
    folder.mkdir(exist_ok=True)
    filename = f"{name}.{suffix}"
    if suffix == "jpg":
        image.convert("RGB").save(folder / filename, quality=86)
    else:
        image.save(folder / filename, optimize=True)
    (folder / "Contents.json").write_text(
        '{\n  "images" : [\n    {\n      "filename" : "%s",\n      "idiom" : "universal"\n    }\n  ],\n'
        '  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n' % filename
    )


def main():
    target_cb, target_cr, lift = target_chroma()
    for source, name in FRAMES.items():
        path = LAYERS / source
        write_imageset(recolor(Image.open(path), target_cb, target_cr, lift), name, path.suffix.lstrip("."))
        print(f"ok: {name}")


if __name__ == "__main__":
    main()
