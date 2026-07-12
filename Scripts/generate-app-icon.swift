#!/usr/bin/swift
// Regenerates the app icon PNGs in
// iPhoneStatus/Resources/Assets.xcassets/AppIcon.appiconset/.
//
// Draws the icon with SwiftUI + ImageRenderer (continuous "squircle" corners,
// matching MetricCard's own corner style) at 1024x1024, then downsamples with
// `sips` to every size the appiconset's Contents.json expects — no PIL/rsvg
// dependency, just the Swift toolchain + macOS's built-in `sips`.
//
// Usage: swift Scripts/generate-app-icon.swift
// (then `xcodegen generate` isn't needed — the appiconset PNGs are picked up
// directly by the existing Contents.json filenames)

import SwiftUI
import AppKit

struct AppIconView: View {
    let indigoLight = Color(red: 0.56, green: 0.54, blue: 0.95)
    let indigoDark = Color(red: 0.27, green: 0.23, blue: 0.64)
    let statusGreen = Color(red: 0.20, green: 0.80, blue: 0.36)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [indigoLight, indigoDark],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 185, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.30), Color.white.opacity(0)],
                                center: UnitPoint(x: 0.5, y: 0.16),
                                startRadius: 0, endRadius: 520
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 185, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.38), radius: 42, x: 0, y: 20)

            phoneGlyph
        }
        .frame(width: 1024, height: 1024)
    }

    var phoneGlyph: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 72, style: .continuous)
                .fill(Color.white)
                .frame(width: 336, height: 568)
                .overlay(
                    RoundedRectangle(cornerRadius: 54, style: .continuous)
                        .fill(indigoDark)
                        .frame(width: 336 - 36, height: 568 - 36)
                        .overlay(alignment: .top) {
                            Capsule()
                                .fill(Color.white)
                                .frame(width: 112, height: 28)
                                .padding(.top, 28)
                        }
                        .overlay(alignment: .bottom) {
                            Capsule()
                                .fill(Color.white.opacity(0.92))
                                .frame(width: 92, height: 8)
                                .padding(.bottom, 24)
                        }
                )
                .shadow(color: .black.opacity(0.28), radius: 22, x: 0, y: 12)

            // Status dot echoes the connected-state green dot used throughout
            // the popover UI (StatusDotRow) — ties the icon to the app's own
            // visual language instead of being a generic decoration.
            Circle()
                .fill(Color.white)
                .frame(width: 138, height: 138)
                .overlay(
                    Circle()
                        .fill(statusGreen)
                        .frame(width: 110, height: 110)
                )
                .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 6)
                .offset(x: 16, y: 16)
        }
    }
}

@MainActor
func renderMaster(to path: String) {
    let renderer = ImageRenderer(content: AppIconView())
    renderer.scale = 1
    renderer.isOpaque = false

    guard let nsImage = renderer.nsImage,
          let tiff = nsImage.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write("Failed to render icon\n".data(using: .utf8)!)
        exit(1)
    }
    try? png.write(to: URL(fileURLWithPath: path))
}

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let appIconSet = root.appendingPathComponent("iPhoneStatus/Resources/Assets.xcassets/AppIcon.appiconset")
let masterPath = NSTemporaryDirectory() + "iphonestatus-icon-master.png"

MainActor.assumeIsolated {
    renderMaster(to: masterPath)
}

// (pixel size, filename) pairs matching AppIcon.appiconset/Contents.json
let targets: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for (size, filename) in targets {
    let outPath = appIconSet.appendingPathComponent(filename).path
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    process.arguments = ["-z", "\(size)", "\(size)", masterPath, "--out", outPath]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try? process.run()
    process.waitUntilExit()
}

print("Wrote \(targets.count) icon sizes to \(appIconSet.path)")
