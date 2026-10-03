#!/usr/bin/env swift
// Renders each Paper SVG in this folder into the asset catalog as @2x/@3x PNGs.
// Their feGaussianBlur filters made iOS re-render them through Core Image on the
// main thread at every new size, a 240-400 ms stall on the onboarding dial.
// Usage: swift Pillie/scripts/method-icons/rasterize.swift

import AppKit

let points = 80
let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let catalog = here.appendingPathComponent("../../Pillie/Assets.xcassets/MethodIcons").standardized

let svgs = try FileManager.default.contentsOfDirectory(at: here, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension == "svg" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

for svg in svgs {
    let name = svg.deletingPathExtension().lastPathComponent
    guard let image = NSImage(contentsOf: svg) else { fatalError("cannot load \(svg.path)") }
    let imageset = catalog.appendingPathComponent("\(name).imageset")
    var entries: [[String: String]] = []
    for scale in [2, 3] {
        let pixels = points * scale
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { fatalError("cannot allocate \(pixels)px bitmap") }
        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: rep)!
        context.imageInterpolation = .high
        NSGraphicsContext.current = context
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        let file = "\(name)@\(scale)x.png"
        try rep.representation(using: .png, properties: [:])!.write(to: imageset.appendingPathComponent(file))
        entries.append(["filename": file, "idiom": "universal", "scale": "\(scale)x"])
    }
    let contents: [String: Any] = [
        "images": [["idiom": "universal", "scale": "1x"]] + entries,
        "info": ["author": "xcode", "version": 1],
    ]
    let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    try json.write(to: imageset.appendingPathComponent("Contents.json"))
    print("\(name): \(points)pt @2x @3x")
}
