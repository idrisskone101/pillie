//
//  OnboardingBackground.swift
//  Pillie
//

import SwiftUI
import UIKit

struct OnboardingBackground: View {
    var blobPhase: CGFloat
    var tier: PerformanceTier = .current

    var body: some View {
        Group {
            if tier == .constrained {
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
                .fill(PillieTheme.coral.opacity(0.16))
                .frame(width: 260, height: 260)
                .offset(x: -130, y: -260)

            Circle()
                .fill(PillieTheme.sage.opacity(0.14))
                .frame(width: 300, height: 300)
                .offset(x: 120, y: 280)
        }
    }

    private var animatedBackground: some View {
        GeometryReader { geo in
            ZStack {
                PillieTheme.bg.ignoresSafeArea()

                // Coral blob - top-left
                BlobShape(phase: blobPhase, seed: 0)
                    .fill(PillieTheme.coral)
                    .frame(width: geo.size.width * 0.7, height: geo.size.height * 0.4)
                    .blur(radius: 80)
                    .opacity(0.4)
                    .blendMode(.multiply)
                    .offset(x: -geo.size.width * 0.25, y: -geo.size.height * 0.25)

                // Lavender blob - top-right
                BlobShape(phase: blobPhase, seed: 1)
                    .fill(PillieTheme.lavender)
                    .frame(width: geo.size.width * 0.6, height: geo.size.height * 0.4)
                    .blur(radius: 80)
                    .opacity(0.6)
                    .offset(x: geo.size.width * 0.2, y: -geo.size.height * 0.1)

                // Sage blob - bottom-center
                BlobShape(phase: blobPhase, seed: 2)
                    .fill(PillieTheme.sage)
                    .frame(width: geo.size.width * 0.8, height: geo.size.height * 0.4)
                    .blur(radius: 80)
                    .opacity(0.4)
                    .blendMode(.multiply)
                    .offset(x: 0, y: geo.size.height * 0.25)

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

// MARK: - BlobShape

struct BlobShape: Shape {
    var phase: CGFloat
    var seed: Int

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        let baseRadius = min(rect.width, rect.height) / 2

        let offsets0 = radiiForSeed(seed, variant: 0)
        let offsets1 = radiiForSeed(seed, variant: 1)

        var points: [CGPoint] = []
        for i in 0..<8 {
            let angle = (CGFloat(i) / 8.0) * .pi * 2
            let r0 = baseRadius * offsets0[i]
            let r1 = baseRadius * offsets1[i]
            let r = r0 + (r1 - r0) * phase
            points.append(CGPoint(x: cx + cos(angle) * r, y: cy + sin(angle) * r))
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

    private func radiiForSeed(_ seed: Int, variant: Int) -> [CGFloat] {
        let table: [[[CGFloat]]] = [
            // seed 0 (coral)
            [[0.85, 1.0, 0.90, 1.05, 0.88, 0.95, 1.02, 0.92],
             [0.92, 0.88, 1.05, 0.90, 1.0, 0.85, 0.95, 1.02]],
            // seed 1 (lavender)
            [[0.90, 0.95, 1.02, 0.88, 0.92, 1.05, 0.85, 1.0],
             [1.0, 0.85, 0.92, 1.02, 0.88, 0.90, 1.05, 0.95]],
            // seed 2 (sage)
            [[1.02, 0.88, 0.95, 1.0, 0.85, 0.92, 0.90, 1.05],
             [0.88, 1.05, 0.85, 0.95, 1.02, 1.0, 0.92, 0.90]],
        ]
        let s = seed % table.count
        let v = variant % 2
        return table[s][v]
    }
}
