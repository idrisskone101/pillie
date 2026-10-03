//
//  OnboardingBackground.swift
//  Pillie
//

import SwiftUI
import UIKit

struct OnboardingBackground: View {
    var blobPhase: CGFloat
    var tier: PerformanceTier = .current
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    var body: some View {
        Group {
            if accessibilityReduceMotion || tier == .constrained {
                constrainedBackground
            } else {
                animatedBackground
            }
        }
        .ignoresSafeArea()
    }

    private var constrainedBackground: some View {
        ZStack {
            LinearGradient(
                colors: [PillieTheme.bg, PillieTheme.lavender.opacity(0.6), PillieTheme.bg],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            PillieTheme.coral.opacity(0.22),
                            PillieTheme.coral.opacity(0.08),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 24,
                        endRadius: 140
                    )
                )
                .frame(width: 260, height: 260)
                .offset(x: -130, y: -260)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            PillieTheme.sage.opacity(0.2),
                            PillieTheme.sage.opacity(0.08),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 28,
                        endRadius: 160
                    )
                )
                .frame(width: 300, height: 300)
                .offset(x: 120, y: 280)
        }
    }

    private var animatedBackground: some View {
        GeometryReader { geo in
            ZStack {
                // One baked image: live 80 pt blurs and blends re-render on the GPU every frame.
                Self.blobs(size: geo.size)
                    .resizable()
                    .scaleEffect(1.04 + 0.04 * blobPhase)
                    .offset(x: -6 + 12 * blobPhase, y: 4 - 8 * blobPhase)

                // Noise/grain overlay
                Image(uiImage: Self.noiseImage)
                    .resizable(resizingMode: .tile)
                    .opacity(0.035)
                    .blendMode(.overlay)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
    }

    @MainActor private static var bakedBlobs: [CGSize: Image] = [:]

    /// The coral, lavender, and sage blobs over the page color, rendered once per size.
    /// 1x is enough: an 80 pt blur leaves no detail to lose.
    @MainActor private static func blobs(size: CGSize) -> Image {
        if let image = bakedBlobs[size] { return image }
        let renderer = ImageRenderer(content: BlobField(size: size))
        renderer.scale = 1
        renderer.isOpaque = true
        let image = renderer.uiImage.map(Image.init(uiImage:)) ?? Image(uiImage: UIImage())
        bakedBlobs[size] = image
        return image
    }

    // MARK: - Noise Image (generated once)

    static let noiseImage: UIImage = {
        let size = 200
        let bytesPerPixel = 4
        let bytesPerRow = size * bytesPerPixel
        var data = [UInt8](repeating: 0, count: size * size * bytesPerPixel)

        for i in stride(from: 0, to: data.count, by: bytesPerPixel) {
            let gray = UInt8.random(in: 0...255)
            data[i] = gray       // R
            data[i + 1] = gray   // G
            data[i + 2] = gray   // B
            data[i + 3] = 255    // A
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &data,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let cgImage = context.makeImage() else {
            return UIImage()
        }

        return UIImage(cgImage: cgImage)
    }()
}

// MARK: - BlobField

private struct BlobField: View {
    let size: CGSize

    var body: some View {
        ZStack {
            PillieTheme.bg

            // Coral blob - top-left
            BlobShape(seed: 0)
                .fill(PillieTheme.coral)
                .frame(width: size.width * 0.7, height: size.height * 0.4)
                .blur(radius: 80)
                .opacity(0.4)
                .blendMode(.multiply)
                .offset(x: -size.width * 0.25, y: -size.height * 0.25)

            // Lavender blob - top-right
            BlobShape(seed: 1)
                .fill(PillieTheme.lavender)
                .frame(width: size.width * 0.6, height: size.height * 0.4)
                .blur(radius: 80)
                .opacity(0.6)
                .offset(x: size.width * 0.2, y: -size.height * 0.1)

            // Sage blob - bottom-center
            BlobShape(seed: 2)
                .fill(PillieTheme.sage)
                .frame(width: size.width * 0.8, height: size.height * 0.4)
                .blur(radius: 80)
                .opacity(0.4)
                .blendMode(.multiply)
                .offset(x: 0, y: size.height * 0.25)
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - BlobShape

struct BlobShape: Shape {
    var seed: Int

    func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        let baseRadius = min(rect.width, rect.height) / 2
        let radii = Self.radii[seed % Self.radii.count]

        let points = (0..<8).map { i in
            let angle = (CGFloat(i) / 8.0) * .pi * 2
            let r = baseRadius * radii[i]
            return CGPoint(x: cx + cos(angle) * r, y: cy + sin(angle) * r)
        }

        var path = Path()
        path.move(to: points[0])

        for i in 0..<8 {
            let current = points[i]
            let next = points[(i + 1) % 8]
            let controlX = (current.x + next.x) / 2
            let controlY = (current.y + next.y) / 2
            path.addQuadCurve(to: next, control: CGPoint(x: controlX, y: controlY))
        }

        path.closeSubpath()
        return path
    }

    private static let radii: [[CGFloat]] = [
        [0.85, 1.0, 0.90, 1.05, 0.88, 0.95, 1.02, 0.92], // coral
        [0.90, 0.95, 1.02, 0.88, 0.92, 1.05, 0.85, 1.0], // lavender
        [1.02, 0.88, 0.95, 1.0, 0.85, 0.92, 0.90, 1.05], // sage
    ]
}
