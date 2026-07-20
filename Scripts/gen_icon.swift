import AppKit

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let tmp = "/tmp/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: tmp)
try! FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)

func render(_ px: Int) -> NSImage {
    let s = CGFloat(px)
    let img = NSImage(size: NSSize(width: s, height: s))
    img.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext

    // 圆角背景（macOS 图标标准圆角约 22.37%）
    let inset = s * 0.08
    let rect = CGRect(x: inset, y: inset, width: s - inset*2, height: s - inset*2)
    let radius = rect.width * 0.2237
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    // 黑色渐变背景
    let grad = NSGradient(colors: [
        NSColor(calibratedRed: 0.13, green: 0.13, blue: 0.14, alpha: 1),
        NSColor(calibratedRed: 0.0, green: 0.0, blue: 0.0, alpha: 1)
    ])!
    path.addClip()
    grad.draw(in: rect, angle: -90)

    // house.fill 符号，饱和天蓝，居中约 62%
    let cfg = NSImage.SymbolConfiguration(pointSize: s * 0.62, weight: .semibold)
    if let sym = NSImage(systemSymbolName: "house.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) {
        let tinted = NSImage(size: sym.size)
        tinted.lockFocus()
        NSColor(calibratedRed: 0.13, green: 0.55, blue: 1.0, alpha: 1).set()
        let r = NSRect(origin: .zero, size: sym.size)
        sym.draw(in: r)
        r.fill(using: .sourceAtop)
        tinted.unlockFocus()

        let sw = sym.size.width, sh = sym.size.height
        let scale = (s * 0.62) / max(sw, sh)
        let dw = sw * scale, dh = sh * scale
        let dx = (s - dw)/2, dy = (s - dh)/2 + s * 0.025
        tinted.draw(in: NSRect(x: dx, y: dy, width: dw, height: dh))
    }
    img.unlockFocus()
    return img
}

for base in sizes {
    for (suffix, scale) in [("", 1), ("@2x", 2)] {
        let px = base * scale
        if px > 1024 { continue }
        let img = render(px)
        guard let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { continue }
        let name = "icon_\(base)x\(base)\(suffix).png"
        try! png.write(to: URL(fileURLWithPath: "\(tmp)/\(name)"))
    }
}
print("iconset ready")
