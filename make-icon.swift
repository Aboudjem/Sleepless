// Sleepless app icon generator (native, AppKit-rendered).
//
// Renders the SAME crescent the menu bar uses -- Apple's `moon.fill` SF Symbol,
// drawn in white on a continuous-curvature ("squircle") violet glass plate -- so
// the Dock/Finder icon is brand-consistent with the native menu-bar glyph and
// never the hand-rolled look that read "cheap". Each iconset size is rendered
// directly from the vector symbol (no raster downscaling) for crisp edges.
//
// Build + run:  swiftc -O -framework AppKit make-icon.swift -o /tmp/mkicon && /tmp/mkicon [outDir]
// Then:         iconutil -c icns Sleepless.iconset -o Sleepless.icns
//
// Output directory = first CLI argument, else the current working directory.
// (No hardcoded paths, so it works from any clone — build.sh passes a temp dir.)
import AppKit

// ---- Brand palette (violet glass; matches the app's tinted popover wash)
let violetTop = NSColor(srgbRed: 150/255.0, green: 104/255.0, blue: 246/255.0, alpha: 1)
let violetBot = NSColor(srgbRed: 109/255.0, green:  64/255.0, blue: 214/255.0, alpha: 1)

let outDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath
let iconset = "\(outDir)/Sleepless.iconset"

// Continuous-curvature squircle path (superellipse, exponent ~5 ~= Apple plate).
func squirclePath(rect: CGRect, n: CGFloat = 5.0) -> CGPath {
    let p = CGMutablePath()
    let cx = rect.midX, cy = rect.midY
    let a = rect.width / 2, b = rect.height / 2
    let steps = 720
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let ct = cos(t), st = sin(t)
        let x = cx + a * copysign(pow(abs(ct), 2.0 / n), ct)
        let y = cy + b * copysign(pow(abs(st), 2.0 / n), st)
        if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
    }
    p.closeSubpath()
    return p
}

func renderIcon(_ S: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext

    // Apple plate grid: ~824 plate on 1024 canvas (≈100px gutter), scaled to S.
    let gutter = S * (100.0 / 1024.0)
    let plate = CGRect(x: gutter, y: gutter, width: S - 2 * gutter, height: S - 2 * gutter)
    let path = squirclePath(rect: plate)

    // Plate fill: vertical violet gradient.
    cg.saveGState()
    cg.addPath(path); cg.clip()
    let cs = CGColorSpaceCreateDeviceRGB()
    let grad = CGGradient(colorsSpace: cs, colors: [violetTop.cgColor, violetBot.cgColor] as CFArray,
                          locations: [0, 1])!
    cg.drawLinearGradient(grad, start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: 0), options: [])

    // Soft top-left glass sheen (subtle radial white, low alpha), clipped to plate.
    let sheen = CGGradient(colorsSpace: cs,
        colors: [NSColor(white: 1, alpha: 0.28).cgColor, NSColor(white: 1, alpha: 0).cgColor] as CFArray,
        locations: [0, 1])!
    let gc = CGPoint(x: plate.minX + plate.width * 0.34, y: plate.maxY - plate.height * 0.28)
    cg.drawRadialGradient(sheen, startCenter: gc, startRadius: 0,
                          endCenter: gc, endRadius: plate.width * 0.62, options: [])
    cg.restoreGState()

    // Native moon.fill crescent, white, centered, ~56% of plate width.
    let cfg = NSImage.SymbolConfiguration(pointSize: plate.width * 0.62, weight: .regular)
    if let sym = NSImage(systemSymbolName: "moon.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) {
        let sz = sym.size
        let scale = (plate.width * 0.56) / max(sz.width, sz.height)
        let w = sz.width * scale, h = sz.height * scale
        let r = NSRect(x: plate.midX - w/2, y: plate.midY - h/2, width: w, height: h)
        // soft drop shadow for depth
        cg.saveGState()
        cg.setShadow(offset: CGSize(width: 0, height: -S*0.006), blur: S*0.012,
                     color: NSColor(srgbRed: 0.16, green: 0.07, blue: 0.35, alpha: 0.55).cgColor)
        let tinted = NSImage(size: sz)
        tinted.lockFocus(); NSColor.white.set()
        sym.draw(in: NSRect(origin: .zero, size: sz))
        NSRect(origin: .zero, size: sz).fill(using: .sourceAtop)
        tinted.unlockFocus()
        tinted.draw(in: r)
        cg.restoreGState()
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func write(_ rep: NSBitmapImageRep, _ path: String) {
    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
}

let fm = FileManager.default
try? fm.removeItem(atPath: iconset)
try? fm.createDirectory(atPath: iconset, withIntermediateDirectories: true)

// 10 standard iconset entries (size, @2x?) -> render each directly from vector.
let specs: [(String, CGFloat)] = [
    ("icon_16x16",16),("icon_16x16@2x",32),("icon_32x32",32),("icon_32x32@2x",64),
    ("icon_128x128",128),("icon_128x128@2x",256),("icon_256x256",256),
    ("icon_256x256@2x",512),("icon_512x512",512),("icon_512x512@2x",1024),
]
for (name, px) in specs { write(renderIcon(px), "\(iconset)/\(name).png") }
write(renderIcon(1024), "\(outDir)/Sleepless-1024.png")
print("rendered iconset (\(specs.count) sizes) + Sleepless-1024.png")
