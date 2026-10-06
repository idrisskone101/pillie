// Renders the paywall phone frame (bezel, Dynamic Island, status icons, blank
// screen) into the PaywallPhone image set. PaywallPhoneMockup overlays the live
// clock and shield copy on top of it.
//
// Run on a Mac from the repo root: swift Pillie/scripts/render-paywall-phone.swift

import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension Color {
    init(hex: String) {
        let v = UInt64(hex, radix: 16)!
        self.init(.sRGB, red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}

let bodyRadius: CGFloat = 46
let screenInset: CGFloat = 7
let screenRadius: CGFloat = 39
let rimLight = Color(hex: "3C3636")
let rimDark = Color(hex: "1C1A1A")
let ink = Color(hex: "292524")

func sideButton(_ length: CGFloat, _ top: CGFloat, _ leading: Bool) -> some View {
    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
        .fill(rimDark)
        .frame(width: 3, height: length)
        .offset(x: leading ? -3 : 3, y: top)
}

struct Phone: View {
    var body: some View {
        RoundedRectangle(cornerRadius: bodyRadius, style: .continuous)
            .fill(Color(hex: "100E0F"))
            .overlay {
                RoundedRectangle(cornerRadius: bodyRadius, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [rimLight, rimDark], startPoint: .top, endPoint: .bottom), lineWidth: 1.5)
            }
            .overlay {
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: screenRadius, style: .continuous).fill(Color(hex: "FCF2F0"))
                    Capsule().fill(Color.black).frame(width: 74, height: 22).padding(.top, 11)
                    HStack(spacing: 5) {
                        Spacer(minLength: 0)
                        Image(systemName: "cellularbars").font(.system(size: 10))
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous).frame(width: 18, height: 8)
                    }
                    .foregroundStyle(ink)
                    .frame(height: 16)
                    .padding(.top, 14)
                    .padding(.horizontal, 28)
                }
                .clipShape(RoundedRectangle(cornerRadius: screenRadius, style: .continuous))
                .padding(screenInset)
            }
            .frame(width: 252, height: 548)
            .overlay(alignment: .topLeading) {
                sideButton(22, 96, true)
                sideButton(40, 140, true)
                sideButton(40, 192, true)
            }
            .overlay(alignment: .topTrailing) { sideButton(62, 156, false) }
            .padding(.horizontal, 3)
            .environment(\.colorScheme, .light)
    }
}

MainActor.assumeIsolated {
for scale in [2, 3] {
    let r = ImageRenderer(content: Phone())
    r.scale = CGFloat(scale)
    let img = r.cgImage!
    let url = URL(fileURLWithPath: "Pillie/Pillie/Assets.xcassets/PaywallPhone.imageset/paywall-phone@\(scale)x.png")
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
}
}
print("ok: PaywallPhone.imageset")
