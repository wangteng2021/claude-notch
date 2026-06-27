import AppKit
import ImageIO
import UniformTypeIdentifiers

// `claude-notch render-demo [outDir]` — renders the card offscreen into PNG
// stills and an animated demo.gif for the README. Pure CoreGraphics/AppKit
// drawing into a bitmap context, so it needs no screen recording and no
// WindowServer (works headless / in CI).

@MainActor
enum DemoRenderer {
    private static let scenes: [(kind: String, title: String, subtitle: String)] = [
        ("permission", "需要你的授权", "Claude 想执行命令，回终端确认"),
        ("waiting", "等待你的输入", "Claude 在等待你的输入"),
        ("done", "Claude 完成了", "轮到你了 →"),
    ]

    private static let canvas = CGSize(width: 720, height: 230)
    private static let pixelScale: CGFloat = 2

    static func run(outDir: String) {
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

        var frames: [CGImage] = []
        var delays: [Double] = []

        for scene in scenes {
            let steps = 9
            for i in 0...steps {
                let t = Double(i) / Double(steps)
                let eased = 1 - pow(1 - t, 3) // easeOutCubic
                guard let image = drawFrame(scene, progress: eased) else { continue }
                frames.append(image)
                delays.append(i == steps ? 1.0 : 0.045) // hold on the last frame
            }
            if let still = drawFrame(scene, progress: 1) {
                writeImage(still, to: "\(outDir)/card-\(scene.kind).png", type: .png)
            }
        }

        writeGIF(frames, delays: delays, to: "\(outDir)/demo.gif")
        FileHandle.standardError.write(Data(
            "Wrote \(frames.count) frames → \(outDir)/demo.gif + \(scenes.count) stills\n".utf8))
    }

    // MARK: Drawing

    private static func drawFrame(_ scene: (kind: String, title: String, subtitle: String),
                                  progress: Double) -> CGImage? {
        let w = Int(canvas.width * pixelScale)
        let h = Int(canvas.height * pixelScale)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        ctx.scaleBy(x: pixelScale, y: pixelScale)
        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsCtx

        let W = canvas.width, H = canvas.height

        // Background gradient: lighter at top, darker at bottom.
        if let gradient = NSGradient(
            starting: NSColor(srgbRed: 0.02, green: 0.03, blue: 0.06, alpha: 1),
            ending: NSColor(srgbRed: 0.11, green: 0.13, blue: 0.18, alpha: 1)) {
            gradient.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: 90)
        }

        // The physical notch (rounded; its top corners sit at the screen edge).
        let notchW: CGFloat = 210, notchH: CGFloat = 34
        let notchRect = NSRect(x: (W - notchW) / 2, y: H - notchH, width: notchW, height: notchH)
        NSColor.black.setFill()
        NSBezierPath(roundedRect: notchRect, xRadius: 10, yRadius: 10).fill()

        // The card hangs from the notch — overlap the notch bottom slightly so
        // the black merges seamlessly (like the iPhone Dynamic Island).
        let cardW: CGFloat = 340, cardH: CGFloat = 64
        let cardTopY = H - notchH + 12
        let cardRect = NSRect(x: (W - cardW) / 2, y: cardTopY - cardH, width: cardW, height: cardH)

        // Entrance: scale around the top-center anchor + fade.
        let s = CGFloat(0.34 + 0.66 * progress)
        ctx.saveGState()
        ctx.setAlpha(CGFloat(progress))
        ctx.translateBy(x: W / 2, y: cardTopY)
        ctx.scaleBy(x: s, y: s)
        ctx.translateBy(x: -W / 2, y: -cardTopY)
        drawCard(cardRect, scene: scene, in: ctx)
        ctx.restoreGState()

        NSGraphicsContext.restoreGraphicsState()
        return ctx.makeImage()
    }

    private static func drawCard(_ rect: NSRect,
                                 scene: (kind: String, title: String, subtitle: String),
                                 in ctx: CGContext) {
        let accent = cardAccentNSColor(scene.kind)
        let path = NSBezierPath(roundedRect: rect, xRadius: 19, yRadius: 19)

        ctx.setShadow(offset: CGSize(width: 0, height: -7), blur: 12,
                      color: NSColor.black.withAlphaComponent(0.5).cgColor)
        NSColor.black.setFill()
        path.fill()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)

        accent.withAlphaComponent(0.55).setStroke()
        path.lineWidth = 1
        path.stroke()

        // Icon
        let iconSize: CGFloat = 20
        let iconRect = NSRect(x: rect.minX + 16, y: rect.midY - iconSize / 2,
                              width: iconSize, height: iconSize)
        symbolImage(scene.kind, accent: accent)?.draw(in: iconRect)

        // Text
        let textX = rect.minX + 16 + 24 + 11
        NSAttributedString(string: scene.title, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]).draw(at: CGPoint(x: textX, y: rect.midY + 2))

        NSAttributedString(string: scene.subtitle, attributes: [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.white.withAlphaComponent(0.72),
        ]).draw(at: CGPoint(x: textX, y: rect.midY - 15))
    }

    private static func symbolImage(_ kind: String, accent: NSColor) -> NSImage? {
        let size = NSImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        let color = NSImage.SymbolConfiguration(paletteColors: [accent])
        let config = size.applying(color)
        return NSImage(systemSymbolName: cardSymbol(kind), accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
    }

    // MARK: Encoding

    private static func writeImage(_ image: CGImage, to path: String, type: UTType) {
        let url = URL(fileURLWithPath: path)
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL, type.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }

    private static func writeGIF(_ images: [CGImage], delays: [Double], to path: String) {
        guard !images.isEmpty else { return }
        let url = URL(fileURLWithPath: path)
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.gif.identifier as CFString, images.count, nil) else { return }

        CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary as String:
            [kCGImagePropertyGIFLoopCount as String: 0]] as CFDictionary)

        for (image, delay) in zip(images, delays) {
            CGImageDestinationAddImage(dest, image, [kCGImagePropertyGIFDictionary as String:
                [kCGImagePropertyGIFUnclampedDelayTime as String: delay]] as CFDictionary)
        }
        CGImageDestinationFinalize(dest)
    }
}
