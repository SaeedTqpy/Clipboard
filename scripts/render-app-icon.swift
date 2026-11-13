#!/usr/bin/env swift
import AppKit
import Foundation

/// Original, resolution-independent glass clipboard illustration.
/// No bundled dependencies: AppKit renders ten sizes and iconutil packs ICNS.
private enum Artwork {
    static func c(_ value: UInt32, _ alpha: CGFloat = 1) -> NSColor {
        NSColor(calibratedRed: CGFloat((value >> 16) & 255) / 255,
                green: CGFloat((value >> 8) & 255) / 255,
                blue: CGFloat(value & 255) / 255, alpha: alpha)
    }

    static func box(_ rect: CGRect, _ radius: CGFloat, _ colors: [NSColor],
                    angle: CGFloat = -30, border: NSColor? = nil, line: CGFloat = 4) {
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        NSGradient(colors: colors)?.draw(in: path, angle: angle)
        NSGraphicsContext.restoreGraphicsState()
        if let border {
            path.lineWidth = line
            border.setStroke()
            path.stroke()
        }
    }

    static func shadow(_ blur: CGFloat, _ offset: CGFloat, _ tint: NSColor,
                       _ action: () -> Void) {
        NSGraphicsContext.saveGraphicsState()
        let s = NSShadow()
        s.shadowBlurRadius = blur
        s.shadowOffset = NSSize(width: 0, height: offset)
        s.shadowColor = tint
        s.set()
        action()
        NSGraphicsContext.restoreGraphicsState()
    }

    static func rotate(_ degrees: CGFloat, at point: CGPoint, _ action: () -> Void) {
        NSGraphicsContext.saveGraphicsState()
        let t = CGAffineTransform(translationX: point.x, y: point.y)
            .rotated(by: degrees * .pi / 180)
            .translatedBy(x: -point.x, y: -point.y)
        NSGraphicsContext.current?.cgContext.concatenate(t)
        action()
        NSGraphicsContext.restoreGraphicsState()
    }

    static func png(_ pixels: Int) throws -> Data {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        ), let gfx = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw NSError(domain: "ClipboardIcon", code: 1)
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = gfx
        gfx.cgContext.scaleBy(x: CGFloat(pixels)/1024, y: CGFloat(pixels)/1024)
        gfx.cgContext.setShouldAntialias(true)
        gfx.imageInterpolation = .high

        // A compact glassy app tile, with translucent cyan-to-violet edges.
        shadow(45, -13, c(0x072A7D, 0.46)) {
            box(CGRect(x: 34,y: 32,width: 956,height: 956),190,
                [c(0x367CB9),c(0x102154),c(0x58318E)],
                border: c(0xA4F3FF,0.81),line: 12)
        }
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: CGRect(x: 46,y: 43,width: 932,height: 932),
                     xRadius: 182,yRadius: 182).addClip()
        let sheen = NSBezierPath()
        sheen.move(to: CGPoint(x: 40,y: 730))
        sheen.curve(to: CGPoint(x: 985,y: 970),
                    controlPoint1: CGPoint(x: 260,y: 1040),
                    controlPoint2: CGPoint(x: 700,y: 860))
        sheen.line(to: CGPoint(x: 40,y: 975))
        sheen.close()
        c(0xBCF6FF,0.23).setFill()
        sheen.fill()
        NSGraphicsContext.restoreGraphicsState()

        // Framed clipboard provides instant recognition at small sizes.
        shadow(34, -12, c(0x09123C,0.64)) {
            box(CGRect(x: 210,y: 183,width: 615,height: 675),100,
                [c(0x50B0E7,0.85),c(0x202869,0.87),c(0x9560D4,0.75)],
                border: c(0xC8F5FF,0.93),line: 17)
        }
        let inner = NSBezierPath(roundedRect: CGRect(x: 239,y: 213,width: 555,height: 614),
                                 xRadius: 78,yRadius: 78)
        inner.lineWidth = 4
        c(0xD1F6FF,0.38).setStroke()
        inner.stroke()

        // Layered copied memories: coral, purple and bright frosted cyan.
        rotate(-10,at:CGPoint(x:530,y:420)) {
            shadow(23,-8,c(0x0A1030,0.43)) {
                box(CGRect(x:305,y:255,width:430,height:310),62,
                    [c(0x6354DB),c(0xD75ACA),c(0xFFAC60)],
                    border:c(0xFFFFFF,0.62),line:8)
            }
        }
        rotate(5,at:CGPoint(x:515,y:463)) {
            box(CGRect(x:269,y:322,width:467,height:306),62,
                [c(0xB1A1F3),c(0x6563DC),c(0xB85FDA)],
                border:c(0xF7E6FF,0.78),line:7)
        }
        rotate(-8,at:CGPoint(x:501,y:504)) {
            shadow(27,-8,c(0x1E6DCD,0.55)) {
                box(CGRect(x:258,y:370,width:477,height:329),62,
                    [c(0xF1F9FF,0.97),c(0x88D8FF,0.95),c(0x1BAFEA,0.94)],
                    border:c(0xFFFFFF,0.86),line:10)
            }
        }
        shadow(18,-5,c(0x0B1D53,0.32)) {
            box(CGRect(x:348,y:447,width:342,height:164),40,
                [c(0xE8F3FF,0.97),c(0xA6BFF6,0.95)],
                border:c(0xFFFFFF,0.83),line:6)
        }

        if pixels >= 64 {
            let glyph = NSAttributedString(string: "⌘V", attributes: [
                .font:NSFont.systemFont(ofSize:100,weight:.medium),
                .foregroundColor:c(0xFFFFFF,0.96)
            ])
            let size = glyph.size()
            glyph.draw(at: CGPoint(x:519-size.width/2,y:524-size.height/2))
        }

        // Polished metal clip and the deep blue aperture.
        shadow(23,-10,c(0x07133A,0.5)) {
            box(CGRect(x:359,y:753,width:310,height:105),48,
                [c(0xFFFFFF),c(0xB9CCEE),c(0xFCFEFF)],
                angle:90,border:c(0xEFF7FF),line:6)
            let tab=NSBezierPath(ovalIn:CGRect(x:452,y:823,width:126,height:127))
            c(0xF4FAFF).setFill();tab.fill()
            let hole=NSBezierPath(ovalIn:CGRect(x:489,y:866,width:54,height:54))
            c(0x12275B).setFill();hole.fill()
        }

        gfx.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        guard let data=bitmap.representation(using:.png,properties:[:]) else {
            throw NSError(domain:"ClipboardIcon",code:2)
        }
        return data
    }
}

func renderIcon() throws {
    guard CommandLine.arguments.count == 2 else {
        throw NSError(domain:"ClipboardIcon",code:3,
                      userInfo:[NSLocalizedDescriptionKey:
                                "Expected output path for Clipboard.icns"])
    }
    let output=URL(fileURLWithPath:CommandLine.arguments[1]).standardizedFileURL
    try FileManager.default.createDirectory(
        at:output.deletingLastPathComponent(),withIntermediateDirectories:true
    )
    let folder=FileManager.default.temporaryDirectory.appendingPathComponent(
        "Clipboard-\(UUID().uuidString).iconset",isDirectory:true
    )
    try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
    defer { try? FileManager.default.removeItem(at:folder) }
    let variants:[(String,Int)]=[
        ("icon_16x16.png",16),("icon_16x16@2x.png",32),
        ("icon_32x32.png",32),("icon_32x32@2x.png",64),
        ("icon_128x128.png",128),("icon_128x128@2x.png",256),
        ("icon_256x256.png",256),("icon_256x256@2x.png",512),
        ("icon_512x512.png",512),("icon_512x512@2x.png",1024)
    ]
    for (file,size) in variants {
        try Artwork.png(size).write(
            to:folder.appendingPathComponent(file),options:.atomic
        )
    }
    let iconutil=Process()
    iconutil.executableURL=URL(fileURLWithPath:"/usr/bin/iconutil")
    iconutil.arguments=["-c","icns",folder.path,"-o",output.path]
    try iconutil.run()
    iconutil.waitUntilExit()
    guard iconutil.terminationStatus == 0,
          FileManager.default.fileExists(atPath:output.path) else {
        throw NSError(domain:"ClipboardIcon",code:4,
                      userInfo:[NSLocalizedDescriptionKey:"iconutil failed"])
    }
    print("Generated app icon:",output.path)
}

do { try renderIcon() } catch {
    fputs("App icon generation failed: \(error)\n",stderr)
    exit(1)
}
