//
//  MilestoneLabelPlacement.swift
//  Pillie
//

import CoreGraphics

/// Where the countdown card's milestone labels go, in left-to-right tray coordinates.
/// The first label starts at the tray's leading edge and the last ends at its trailing edge; the others
/// center on their nodes. Labels never cross the tray or each other. When the natural widths cannot fit,
/// the widest labels are narrowed first, and they wrap or shrink inside that width.
enum MilestoneLabelPlacement {
    struct Frame: Equatable {
        let x: CGFloat
        let width: CGFloat
    }

    static let gap: CGFloat = 6

    static func frames(centers: [CGFloat], widths natural: [CGFloat], trayWidth: CGFloat) -> [Frame] {
        let count = min(centers.count, natural.count)
        guard count > 0 else { return [] }
        let widths = capped(Array(natural.prefix(count)), toFit: trayWidth - gap * CGFloat(count - 1))

        var xs = (0..<count).map { index -> CGFloat in
            if index == 0 { return 0 }
            if index == count - 1 { return trayWidth - widths[index] }
            return min(max(centers[index] - widths[index] / 2, 0), trayWidth - widths[index])
        }
        for index in 1..<count {
            xs[index] = max(xs[index], xs[index - 1] + widths[index - 1] + gap)
        }
        xs[count - 1] = trayWidth - widths[count - 1]
        for index in stride(from: count - 2, through: 0, by: -1) {
            xs[index] = min(xs[index], xs[index + 1] - gap - widths[index])
        }
        xs[0] = 0
        return zip(xs, widths).map { Frame(x: $0, width: $1) }
    }

    /// Lowers one shared cap on the widest labels until the row fits `available`.
    private static func capped(_ widths: [CGFloat], toFit available: CGFloat) -> [CGFloat] {
        guard widths.reduce(0, +) > available else { return widths }
        let sorted = widths.sorted()
        var fixed: CGFloat = 0
        for (index, width) in sorted.enumerated() {
            let cap = (available - fixed) / CGFloat(sorted.count - index)
            if width > cap { return widths.map { min($0, floor(cap)) } }
            fixed += width
        }
        return widths
    }
}
