// Sleepless app icon generator (native, AppKit-rendered).
//
// Renders the SAME coffee cup the menu bar uses -- Apple's `cup.and.saucer.fill`
// SF Symbol, drawn in white on a continuous-curvature ("squircle") Liquid-Glass
// plate carrying the brand's indigo -> violet -> fuchsia gradient -- so the
// Dock/Finder icon is brand-consistent with the native menu-bar glyph and reads
// premium, not hand-rolled. The full white cup is the "caffeinated / kept awake"
// mark; a soft aurora steam wisp rises from it (the brand signature) at larger
// sizes only, so the small Dock/menu sizes stay clean and legible. Each iconset
// size is rendered directly from the vector symbol (no raster downscaling).
//
// Build + run:  swiftc -O -framework AppKit make-icon.swift -o /tmp/mkicon && /tmp/mkicon [outDir]
// Then:         iconutil -c icns Sleepless.iconset -o Sleepless.icns
//
// Output directory = first CLI argument, else the current working directory.
// (No hardcoded paths, so it works from any clone — build.sh passes a temp dir.)
import AppKit

// ---- Brand palette (2026 redesign): indigo -> violet -> fuchsia diagonal gradient,
// lighter at the top-left so it harmonises with the system's icon lighting. The
// white cup reads cleanly on top; the violet mid-stop matches the popover accent.
let plateTop = NSColor(srgbRed: 124/255.0, green: 140/255.0, blue: 255/255.0, alpha: 1) // #7C8CFF light indigo
let plateMid = NSColor(srgbRed: 139/255.0, green:  92/255.0, blue: 246/255.0, alpha: 1) // #8B5CF6 violet
let plateBot = NSColor(srgbRed: 192/255.0, green:  38/255.0, blue: 211/255.0, alpha: 1) // #C026D3 fuchsia/magenta

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

    // Plate fill: indigo -> violet -> fuchsia diagonal gradient (lighter top-left,
    // deeper bottom-right) so it agrees with the system icon lighting.
    cg.saveGState()
    cg.addPath(path); cg.clip()
    let cs = CGColorSpaceCreateDeviceRGB()
    let grad = CGGradient(colorsSpace: cs,
        colors: [plateTop.cgColor, plateMid.cgColor, plateBot.cgColor] as CFArray,
        locations: [0, 0.5, 1])!
    cg.drawLinearGradient(grad,
        start: CGPoint(x: plate.minX, y: plate.maxY),   // top-left (light indigo)
        end:   CGPoint(x: plate.maxX, y: plate.minY),   // bottom-right (deep fuchsia)
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

    // Soft top-left glass sheen (specular highlight, radial white), clipped to plate.
    let sheen = CGGradient(colorsSpace: cs,
        colors: [NSColor(white: 1, alpha: 0.32).cgColor, NSColor(white: 1, alpha: 0).cgColor] as CFArray,
        locations: [0, 1])!
    let gc = CGPoint(x: plate.minX + plate.width * 0.32, y: plate.maxY - plate.height * 0.26)
    cg.drawRadialGradient(sheen, startCenter: gc, startRadius: 0,
                          endCenter: gc, endRadius: plate.width * 0.66, options: [])

    // Faint white "lit from within" glow behind the cup for depth.
    let glow = CGGradient(colorsSpace: cs,
        colors: [NSColor(white: 1, alpha: 0.12).cgColor, NSColor(white: 1, alpha: 0).cgColor] as CFArray,
        locations: [0, 1])!
    let glowC = CGPoint(x: plate.midX, y: plate.midY)
    cg.drawRadialGradient(glow, startCenter: glowC, startRadius: 0,
                          endCenter: glowC, endRadius: plate.width * 0.44, options: [])

    // Aurora steam signature: soft violet -> fuchsia wisps that CURL sideways and
    // dissipate at rounded tips, so the mark reads as steam (never a flame) while still
    // carrying the brand gradient. Two staggered curls at large sizes; one bolder curl
    // at small sizes so it survives in the Dock. The white cup always leads.
    if S >= 24 {
        let single = S <= 64
        // each wisp: (baseDx, lateral drift toward tip, height fraction, base width)
        // Both wisps lean the same way (a soft draft) with different heights/widths/curl,
        // so they read as drifting steam, not symmetric "ears".
        let wisps: [(dx: CGFloat, drift: CGFloat, hf: CGFloat, w: CGFloat)] = single
            ? [(-0.01, 0.13, 1.0, 0.10)]
            : [(-0.045, 0.05, 1.0, 0.072), (0.075, 0.16, 0.78, 0.058)]
        let baseY = plate.midY + plate.height * 0.10     // at the cup rim
        let fullTop = plate.maxY - plate.height * 0.06
        // faint vapor halo (well below the flame-like glow of the prior pass)
        let halo = CGGradient(colorsSpace: cs,
            colors: [NSColor(srgbRed: 0.93, green: 0.52, blue: 1.0, alpha: 0.20).cgColor,
                     NSColor(srgbRed: 0.93, green: 0.52, blue: 1.0, alpha: 0).cgColor] as CFArray,
            locations: [0, 1])!
        let haloC = CGPoint(x: plate.midX, y: (baseY + fullTop) / 2)
        cg.drawRadialGradient(halo, startCenter: haloC, startRadius: 0,
                              endCenter: haloC, endRadius: plate.width * 0.16, options: [])
        for wp in wisps {
            let topY = baseY + (fullTop - baseY) * wp.hf
            let x0 = plate.midX + plate.width * wp.dx
            let steps = 30
            func pt(_ u: CGFloat, _ side: CGFloat) -> CGPoint {
                let y = baseY + (topY - baseY) * u
                let curl = plate.width * wp.drift * (u * u)            // drift grows toward the tip = curl
                let wave = plate.width * 0.028 * sin(u * .pi * 2.1)    // gentle squiggle
                let half = (plate.width * wp.w) * pow(1 - u, 0.55) * 0.5 + plate.width * 0.004  // taper to a rounded tip
                return CGPoint(x: x0 + curl + wave + side * half, y: y)
            }
            let ribbon = CGMutablePath()
            ribbon.move(to: pt(0, -1))
            for i in 1...steps { ribbon.addLine(to: pt(CGFloat(i)/CGFloat(steps), -1)) }
            for i in stride(from: steps, through: 0, by: -1) { ribbon.addLine(to: pt(CGFloat(i)/CGFloat(steps), 1)) }
            ribbon.closeSubpath()
            cg.saveGState(); cg.addPath(ribbon); cg.clip()
            let steam = CGGradient(colorsSpace: cs,
                colors: [NSColor(srgbRed: 0.80, green: 0.70, blue: 1.0, alpha: 0.92).cgColor,  // bright violet
                         NSColor(srgbRed: 0.95, green: 0.60, blue: 1.0, alpha: 0.80).cgColor,  // fuchsia
                         NSColor(srgbRed: 1.0,  green: 0.78, blue: 1.0, alpha: 0.0).cgColor]  as CFArray, // dissipate
                locations: [0, 0.55, 1])!
            cg.drawLinearGradient(steam, start: CGPoint(x: x0, y: baseY),
                                  end: CGPoint(x: x0 + plate.width * wp.drift, y: topY), options: [])
            cg.restoreGState()
        }
    }
    cg.restoreGState()

    // Native cup.and.saucer.fill, white, centered. The cup is the brand object so it
    // leads; at small sizes it grows bolder (and heavier weight) so it survives the Dock.
    let small = S <= 64
    let cupFrac: CGFloat = small ? 0.66 : 0.58
    let cfg = NSImage.SymbolConfiguration(pointSize: plate.width * (small ? 0.74 : 0.64),
                                          weight: small ? .medium : .regular)
    if let sym = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) {
        let sz = sym.size
        let scale = (plate.width * cupFrac) / max(sz.width, sz.height)
        let w = sz.width * scale, h = sz.height * scale
        let r = NSRect(x: plate.midX - w/2, y: plate.midY - h/2, width: w, height: h)
        // soft violet chromatic drop shadow for depth (samples the plate mid-stop)
        cg.saveGState()
        cg.setShadow(offset: CGSize(width: 0, height: -S*0.006), blur: S*0.014,
                     color: NSColor(srgbRed: 0.32, green: 0.12, blue: 0.50, alpha: 0.55).cgColor)
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
