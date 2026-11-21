// App.swift. Sleepless: a standalone menu-bar utility that keeps your Mac awake
// normally (via IOKit idle-sleep assertion, default ON) and optionally with the
// lid closed (on battery, no external display) via `pmset disablesleep`.
//
// Mechanism:
//   Normal awake (default ON, no root):
//     IOKit IOPMAssertion (PreventUserIdleSystemSleep) — auto-releases on quit/crash.
//   Lid-closed awake (opt-in, via scoped /etc/sudoers.d drop-in):
//     ON : sudo pmset -a disablesleep 1
//     OFF: sudo pmset -a disablesleep 0
//     READ (no root): pmset -g | grep -i SleepDisabled  (value 1 = ON; 0/absent = OFF)
//   disablesleep is runtime-only and resets to 0 on reboot; the app never auto re-arms it.
//
// Fail-safe protections layer on top (no root daemon):
//   1. Auto-off timer (Off / 15m / 30m / 1h / 2h / 4h / 8h) — one-shot in-memory Timer.
//   2. Battery-floor cutoff (5%–50%, default 15%) — always wins on battery.
//   3. Low-Power-Mode auto-off — on battery, steps aside unless forced on this session.
//   4. Thermal cutoff on AC or battery: CPU temperature limit (60–95 °C or Off, default
//      80 °C, mean of the hottest 60% of CPU die sensors) and macOS thermalState limit
//      (Fair / Serious / Critical / Off, default Serious), with a 30-minute graph.
//   5. Crash safety: signal handlers plus a detached, unprivileged watchdog loop that
//      restores `disablesleep 0` if the app dies or its lease goes stale for 2 minutes.
//
// Build: Command Line Tools `swiftc`, NO Xcode project.
//   swiftc -O -parse-as-library -target arm64-apple-macos26.0 -framework AppKit \
//          -framework ServiceManagement -framework IOKit App.swift -o /tmp/Sleepless
import AppKit
import IOKit.pwr_mgt
import ServiceManagement

// MARK: - Tunables & Persistence Keys
private let pollInterval: TimeInterval = 60

private let floorKey = "batteryFloorPercent"
private let floorDefault = 15
private let floorMin = 5
private let floorMax = 50

private let timerStopMinutes = [0, 15, 30, 60, 120, 240, 480]
private let timerStopLabels = ["Off", "15m", "30m", "1h", "2h", "4h", "8h"]

private let thermalKey = "thermalCutoffTempC"
private let thermalStateKey = "thermalStateCutoffLevel"
private let lastStopKey = "lastStopReason"
private let thermalStopTemps = [60, 65, 70, 75, 80, 85, 90, 95, 0]       // 0 = Off (far right)
private let thermalDefaultTemp = 80
private let thermalStateStops = [1, 2, 3, 0]                             // Fair, Serious, Critical, Off (far right)
private let thermalStateDefault = 2                                      // Serious
private let thermalSampleInterval: TimeInterval = 15
private let thermalHistoryWindow: TimeInterval = 30 * 60                 // 30 minutes
private let leaseRefreshInterval: TimeInterval = 30
private let leaseMaxAgeSeconds = 120                                     // 2-minute freeze watchdog

private func thermalCutoffRisk(_ tempC: Int) -> (label: String, color: NSColor) {
    switch tempC {
    case 0:       return ("Unprotected", .systemRed)
    case ...70:   return ("Safe",        .systemGreen)
    case 71...80: return ("Balanced",    .systemTeal)
    case 81...90: return ("High",        .systemOrange)
    default:      return ("Extreme",     .systemRed)
    }
}

private func thermalStateStopDisplay(_ level: Int) -> (label: String, color: NSColor) {
    switch level {
    case 1:  return ("Fair",     .systemYellow)
    case 2:  return ("Serious",  .systemOrange)
    case 3:  return ("Critical", .systemRed)
    default: return ("Off",      .systemRed)
    }
}

private struct ThermalSample {
    let date: Date
    let tempC: Double?
    let state: ProcessInfo.ThermalState
}

// Exact 80-byte AppleSMC user-client struct layout (non-root read-only access).
private struct SMCKeyData_t {
    var key: UInt32 = 0
    var versMajor: UInt8 = 0
    var versMinor: UInt8 = 0
    var versBuild: UInt8 = 0
    var versReserved: UInt8 = 0
    var versRelease: UInt16 = 0
    var pad1: UInt16 = 0
    var pLimitVersion: UInt16 = 0
    var pLimitLength: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
    var pad2: (UInt8, UInt8, UInt8) = (0, 0, 0)
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var pad3: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
               (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
}

// Non-root CPU die temperature reader. Primary: the PMU "tdie" die sensors via the
// private IOKit HID event system (they track macOS thermal pressure). Fallback: AppleSMC
// Te*/Tp* (Apple Silicon) or TC* (Intel) keys; on Apple Silicon many of those are
// hotspot sensors that read 20-30 °C above the die under load. Reports the mean of the
// hottest 60% of sensors, averaged across 5x 20ms bursts to avoid jitter.
private final class ThermalSensor: @unchecked Sendable {
    private struct SMCKeyMeta {
        let key: UInt32
        let dataSize: UInt32
        let isFloat: Bool   // true = "flt " (4B), false = "sp78" (2B)
    }

    private typealias CreateFn = @convention(c) (CFAllocator?) -> Unmanaged<AnyObject>?
    private typealias SetMatchFn = @convention(c) (AnyObject, CFDictionary) -> Void
    private typealias CopyServicesFn = @convention(c) (AnyObject) -> Unmanaged<CFArray>?
    private typealias CopyEventFn = @convention(c) (AnyObject, Int64, Int32, Int64) -> Unmanaged<AnyObject>?
    private typealias GetFloatFn = @convention(c) (AnyObject, Int32) -> Double
    private typealias CopyPropFn = @convention(c) (AnyObject, CFString) -> Unmanaged<AnyObject>?

    private let lock = NSLock()
    private var smcConn: io_connect_t = 0
    private var cpuKeys: [SMCKeyMeta] = []

    // HID die sensors (primary source)
    private var hidClient: AnyObject?
    private var hidCopyServices: CopyServicesFn?
    private var hidCopyEvent: CopyEventFn?
    private var hidGetFloat: GetFloatFn?
    private var hidCopyProp: CopyPropFn?

    init() {
        setupSMC()
        setupHIDFallback()
    }

    deinit {
        if smcConn != 0 { IOServiceClose(smcConn) }
    }

    private static func fourCC(_ s: String) -> UInt32 {
        s.utf8.reduce(0) { ($0 << 8) | UInt32($1) }
    }

    private static func fromFourCC(_ v: UInt32) -> String {
        String(bytes: [UInt8((v >> 24) & 0xff), UInt8((v >> 16) & 0xff),
                       UInt8((v >> 8) & 0xff), UInt8(v & 0xff)], encoding: .ascii) ?? "????"
    }

    private func smcCall(_ input: inout SMCKeyData_t) -> (kern_return_t, SMCKeyData_t) {
        var output = SMCKeyData_t()
        var outSize = MemoryLayout<SMCKeyData_t>.size
        let r = IOConnectCallStructMethod(smcConn, 2, &input, MemoryLayout<SMCKeyData_t>.size, &output, &outSize)
        return (r, output)
    }

    private func setupSMC() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return }
        var conn: io_connect_t = 0
        let kr = IOServiceOpen(service, mach_task_self_, 0, &conn)
        IOObjectRelease(service)
        guard kr == kIOReturnSuccess, conn != 0 else { return }
        smcConn = conn

        var countInp = SMCKeyData_t()
        countInp.key = Self.fourCC("#KEY")
        countInp.data8 = 9 // kSMCGetKeyInfo
        let (r1, co1) = smcCall(&countInp)
        guard r1 == kIOReturnSuccess, co1.result == 0 else { return }
        countInp.dataSize = co1.dataSize
        countInp.data8 = 5 // kSMCReadKey
        let (r2, co2) = smcCall(&countInp)
        guard r2 == kIOReturnSuccess, co2.result == 0 else { return }
        let keyCount = (UInt32(co2.bytes.0) << 24) | (UInt32(co2.bytes.1) << 16)
                     | (UInt32(co2.bytes.2) << 8) | UInt32(co2.bytes.3)

        let fltType = Self.fourCC("flt ")
        let sp78Type = Self.fourCC("sp78")

        // Discover CPU core temperature keys once:
        // Apple Silicon uses Te0* (efficiency cores) and Tp0*/Tp1*/Tp2* (performance cores),
        // skipping aggregate max keys (Tex*/Tpx*). Each core's current sensor is cached.
        var found: [SMCKeyMeta] = []
        for i in 0..<keyCount {
            var idxInp = SMCKeyData_t()
            idxInp.data8 = 8 // kSMCGetKeyFromIndex
            idxInp.data32 = i
            let (ri, oi) = smcCall(&idxInp)
            guard ri == kIOReturnSuccess, oi.result == 0 else { continue }
            let name = Self.fromFourCC(oi.key)
            let isAppleSiliconCPU = (name.hasPrefix("Te") || name.hasPrefix("Tp"))
                                 && !name.hasPrefix("Tex") && !name.hasPrefix("Tpx")
            let isIntelCPU = name.hasPrefix("TC") && (name.hasSuffix("C") || name.hasSuffix("D") || name.hasSuffix("P"))
            guard isAppleSiliconCPU || isIntelCPU else { continue }

            var infoInp = SMCKeyData_t()
            infoInp.key = oi.key
            infoInp.data8 = 9
            let (rk, ok) = smcCall(&infoInp)
            guard rk == kIOReturnSuccess, ok.result == 0 else { continue }
            let isFloat = (ok.dataType == fltType && ok.dataSize == 4)
            let isSP78 = (ok.dataType == sp78Type && ok.dataSize == 2)
            guard isFloat || isSP78 else { continue }

            let meta = SMCKeyMeta(key: oi.key, dataSize: ok.dataSize, isFloat: isFloat)
            if let v = readSMCKeyLocked(meta), v > 15 && v < 118 {
                found.append(meta)
            }
        }
        cpuKeys = found
    }

    private func readSMCKeyLocked(_ meta: SMCKeyMeta) -> Double? {
        var inp = SMCKeyData_t()
        inp.key = meta.key
        inp.dataSize = meta.dataSize
        inp.data8 = 5 // kSMCReadKey
        let (r, o) = smcCall(&inp)
        guard r == kIOReturnSuccess, o.result == 0 else { return nil }
        if meta.isFloat {
            let bits = UInt32(o.bytes.0) | (UInt32(o.bytes.1) << 8)
                     | (UInt32(o.bytes.2) << 16) | (UInt32(o.bytes.3) << 24)
            return Double(Float(bitPattern: bits))
        } else {
            let raw = Int16(bitPattern: (UInt16(o.bytes.0) << 8) | UInt16(o.bytes.1))
            return Double(raw) / 256.0
        }
    }

    private func setupHIDFallback() {
        guard let h = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW),
              let sCreate = dlsym(h, "IOHIDEventSystemClientCreate"),
              let sMatch = dlsym(h, "IOHIDEventSystemClientSetMatching"),
              let sServices = dlsym(h, "IOHIDEventSystemClientCopyServices"),
              let sEvent = dlsym(h, "IOHIDServiceClientCopyEvent"),
              let sFloat = dlsym(h, "IOHIDEventGetFloatValue"),
              let sProp = dlsym(h, "IOHIDServiceClientCopyProperty") else { return }
        let create = unsafeBitCast(sCreate, to: CreateFn.self)
        let setMatch = unsafeBitCast(sMatch, to: SetMatchFn.self)
        guard let c = create(kCFAllocatorDefault)?.takeRetainedValue() else { return }
        setMatch(c, ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 5] as CFDictionary)
        hidClient = c
        hidCopyServices = unsafeBitCast(sServices, to: CopyServicesFn.self)
        hidCopyEvent = unsafeBitCast(sEvent, to: CopyEventFn.self)
        hidGetFloat = unsafeBitCast(sFloat, to: GetFloatFn.self)
        hidCopyProp = unsafeBitCast(sProp, to: CopyPropFn.self)
    }

    /// Mean of the hottest 60% of readings: ignores idle or parked cores without
    /// letting a single hot core trip the cutoff.
    private static func hottestShareMean(_ temps: [Double]) -> Double {
        let n = max(1, Int((Double(temps.count) * 0.6).rounded(.up)))
        let top = temps.sorted(by: >).prefix(n)
        return top.reduce(0, +) / Double(top.count)
    }

    /// Single-pass reading: hottest 60% of CPU die sensors (HID, fallback AppleSMC).
    func readCelsius() -> Double? {
        lock.lock()
        defer { lock.unlock() }

        if let client = hidClient, let copyServices = hidCopyServices,
           let copyEvent = hidCopyEvent, let getFloat = hidGetFloat, let copyProp = hidCopyProp,
           let services = copyServices(client)?.takeRetainedValue() as? [AnyObject] {
            var dieTemps: [Double] = []
            for svc in services {
                let name = (copyProp(svc, "Product" as CFString)?.takeRetainedValue() as? String) ?? ""
                if name.localizedCaseInsensitiveContains("tcal") { continue }
                guard let ev = copyEvent(svc, 15, 0, 0)?.takeRetainedValue() else { continue }
                let v = getFloat(ev, 15 << 16)
                if v > 15 && v < 118 && (name.contains("tdie") || name.contains("MTR Temp")) {
                    dieTemps.append(v)
                }
            }
            if !dieTemps.isEmpty { return Self.hottestShareMean(dieTemps) }
        }

        if smcConn != 0, !cpuKeys.isEmpty {
            var coreTemps: [Double] = []
            coreTemps.reserveCapacity(cpuKeys.count)
            for meta in cpuKeys {
                if let v = readSMCKeyLocked(meta), v > 15 && v < 118 {
                    coreTemps.append(v)
                }
            }
            if !coreTemps.isEmpty { return Self.hottestShareMean(coreTemps) }
        }
        return nil
    }

    /// Burst-averaged reading: takes `count` readings spaced `spacingMs` apart.
    func readSmoothedCelsius(count: Int = 5, spacingMs: UInt32 = 20) -> Double? {
        var socReadings: [Double] = []
        socReadings.reserveCapacity(count)
        for i in 0..<count {
            if let s = readCelsius() { socReadings.append(s) }
            if i + 1 < count { usleep(spacingMs * 1000) }
        }
        return socReadings.isEmpty ? nil : socReadings.reduce(0, +) / Double(socReadings.count)
    }
}

private func thermalDisplay(_ state: ProcessInfo.ThermalState) -> (name: String, color: NSColor) {
    switch state {
    case .nominal:  return ("Nominal",  .systemGreen)
    case .fair:     return ("Fair",     .systemYellow)
    case .serious:  return ("Serious",  .systemOrange)
    case .critical: return ("Critical", .systemRed)
    @unknown default: return ("Unknown", .secondaryLabelColor)
    }
}

// MARK: - Menu-bar coffee glyph (native SF Symbols, MONOCHROME template — state by SHAPE)
enum SleepGlyph {
    case off          // sleeping normally: cup on saucer, no steam
    case awake        // master ON (normal idle-sleep prevented): steaming outline cup
    case lidClosed    // lid-closed ON (AC): steaming filled cup
    case lidArmed     // lid-closed ON (battery, safety net live): steaming filled cup + dot
}

private func makeCupGlyph(_ glyph: SleepGlyph) -> NSImage {
    let weight: NSFont.Weight = (glyph == .off) ? .regular : .semibold
    let cfg = NSImage.SymbolConfiguration(pointSize: 15, weight: weight).applying(.init(scale: .medium))
    let name: String
    switch glyph {
    case .off:       name = "cup.and.saucer"
    case .awake:     name = "cup.and.heat.waves"
    case .lidClosed: name = "cup.and.heat.waves.fill"
    case .lidArmed:  name = "cup.and.heat.waves.fill"
    }
    let base = NSImage(systemSymbolName: name, accessibilityDescription: "Sleepless")?
        .withSymbolConfiguration(cfg)
        ?? NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: "Sleepless")
        ?? NSImage()

    // Normalize every glyph to the exact same canvas size so swapping states never
    // resizes the status-bar button (which causes NSPopover to jump on macOS).
    let canvas = NSSize(width: 20, height: 18)
    let composed = NSImage(size: canvas)
    composed.lockFocus()
    let sz = base.size
    let drawRect = NSRect(x: (canvas.width - sz.width) / 2,
                          y: (canvas.height - sz.height) / 2,
                          width: sz.width,
                          height: sz.height)
    base.draw(in: drawRect)
    if glyph == .lidArmed {
        let d: CGFloat = 4.5
        let dot = NSBezierPath(ovalIn: NSRect(x: canvas.width - d - 0.5, y: canvas.height - d - 0.5, width: d, height: d))
        NSColor.black.setFill()
        dot.fill()
    }
    composed.unlockFocus()
    composed.isTemplate = true
    return composed
}

// MARK: - Brand Accent & Native Liquid Glass Views
private let brandAccent = NSColor(srgbRed: 139/255.0, green: 92/255.0, blue: 246/255.0, alpha: 1)     // #8B5CF6
private let brandAccentSoft = NSColor(srgbRed: 167/255.0, green: 139/255.0, blue: 250/255.0, alpha: 1) // #A78BFA

private final class GlassView: NSVisualEffectView { override var isFlipped: Bool { true } }

private final class CardView: NSView {
    enum Highlight { case none, subtle, strong }
    var highlight: Highlight = .none { didSet { if highlight != oldValue { needsDisplay = true } } }
    override var isFlipped: Bool { true }
    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() {
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        switch highlight {
        case .strong:
            layer?.backgroundColor = brandAccent.withAlphaComponent(dark ? 0.19 : 0.11).cgColor
            layer?.borderColor = brandAccent.withAlphaComponent(dark ? 0.62 : 0.48).cgColor
        case .subtle:
            layer?.backgroundColor = brandAccent.withAlphaComponent(dark ? 0.10 : 0.06).cgColor
            layer?.borderColor = brandAccent.withAlphaComponent(dark ? 0.36 : 0.26).cgColor
        case .none:
            layer?.backgroundColor = (dark ? NSColor.white.withAlphaComponent(0.055)
                                           : NSColor.black.withAlphaComponent(0.04)).cgColor
            layer?.borderColor = (dark ? NSColor.white.withAlphaComponent(0.085)
                                       : NSColor.black.withAlphaComponent(0.065)).cgColor
        }
        layer?.borderWidth = 1
        layer?.cornerRadius = 12
        layer?.cornerCurve = .continuous
    }
}

private final class HairlineView: NSView {
    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() {
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        layer?.backgroundColor = (dark ? NSColor.white.withAlphaComponent(0.08)
                                       : NSColor.black.withAlphaComponent(0.07)).cgColor
    }
}

private final class PillBadge: NSView {
    private let dot = NSView()
    private let label = NSTextField(labelWithString: "")
    private let trailingIcon = NSImageView()
    private var pillColor: NSColor = .secondaryLabelColor
    private var trackingArea: NSTrackingArea?
    private var hoverPopover: NSPopover?

    var hoverTitle: String?
    var hoverMessage: String?

    override var isFlipped: Bool { true }
    override var wantsUpdateLayer: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 3
        addSubview(dot)

        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        addSubview(label)

        trailingIcon.imageScaling = .scaleProportionallyDown
        trailingIcon.isHidden = true
        addSubview(trailingIcon)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    func configure(text: String, color: NSColor, showDot: Bool = true, trailingSymbol: String? = nil) {
        pillColor = color
        label.stringValue = text
        label.textColor = color
        label.sizeToFit()
        dot.isHidden = !showDot
        dot.layer?.backgroundColor = color.cgColor

        let hasIcon = trailingSymbol != nil
        if let sym = trailingSymbol {
            let cfg = NSImage.SymbolConfiguration(pointSize: 10.5, weight: .semibold)
            let img = NSImage(systemSymbolName: sym, accessibilityDescription: "Info")?.withSymbolConfiguration(cfg)
            img?.isTemplate = true
            trailingIcon.image = img
            trailingIcon.contentTintColor = color
            trailingIcon.isHidden = false
        } else {
            trailingIcon.isHidden = true
        }

        let padH: CGFloat = 8
        let dotW: CGFloat = showDot ? 6 : 0
        let dotGap: CGFloat = showDot ? 5 : 0
        let iconW: CGFloat = hasIcon ? 12 : 0
        let iconGap: CGFloat = hasIcon ? 4 : 0
        let totalW = padH + dotW + dotGap + ceil(label.frame.width) + iconGap + iconW + padH
        let totalH: CGFloat = 20
        frame.size = NSSize(width: totalW, height: totalH)
        if showDot {
            dot.frame = NSRect(x: padH, y: (totalH - 6) / 2, width: 6, height: 6)
        }
        let labelX = padH + dotW + dotGap
        label.frame = NSRect(x: labelX, y: (totalH - label.frame.height) / 2 - 0.5,
                             width: ceil(label.frame.width), height: label.frame.height)
        if hasIcon {
            trailingIcon.frame = NSRect(x: labelX + ceil(label.frame.width) + iconGap,
                                        y: (totalH - 12) / 2, width: 12, height: 12)
        }
        needsDisplay = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea { removeTrackingArea(ta) }
        let ta = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(ta)
        trackingArea = ta
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        guard let msg = hoverMessage, window != nil else { return }
        showHoverPopover(title: hoverTitle, message: msg)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        dismissHoverPopover()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil { dismissHoverPopover() }
    }

    func dismissHoverPopover() {
        hoverPopover?.performClose(nil)
        hoverPopover = nil
    }

    private func showHoverPopover(title: String?, message: String) {
        dismissHoverPopover()
        let popW: CGFloat = 258
        let pad: CGFloat = 12
        let textW = popW - pad * 2

        let bodyLabel = NSTextField(wrappingLabelWithString: message)
        bodyLabel.font = .systemFont(ofSize: 11.5)
        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.maximumNumberOfLines = 0
        bodyLabel.preferredMaxLayoutWidth = textW
        let bodySize = bodyLabel.sizeThatFits(NSSize(width: textW, height: .greatestFiniteMagnitude))

        let hasTitle = (title != nil && !title!.isEmpty)
        let titleH: CGFloat = hasTitle ? 18 : 0
        let titleGap: CGFloat = hasTitle ? 5 : 0
        let popH = pad + titleH + titleGap + ceil(bodySize.height) + pad

        let container = GlassView(frame: NSRect(x: 0, y: 0, width: popW, height: popH))
        container.material = .popover
        container.blendingMode = .behindWindow
        container.state = .active

        if let title, !title.isEmpty {
            let warnIcon = NSImageView(frame: NSRect(x: pad, y: pad + 1, width: 14, height: 14))
            let cfg = NSImage.SymbolConfiguration(pointSize: 11.5, weight: .semibold)
            let img = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(cfg)
            img?.isTemplate = true
            warnIcon.image = img
            warnIcon.contentTintColor = pillColor
            container.addSubview(warnIcon)

            let tLbl = NSTextField(labelWithString: title)
            tLbl.font = .systemFont(ofSize: 12, weight: .semibold)
            tLbl.textColor = .labelColor
            tLbl.frame = NSRect(x: pad + 19, y: pad, width: textW - 19, height: 16)
            container.addSubview(tLbl)
        }

        bodyLabel.frame = NSRect(x: pad, y: pad + titleH + titleGap, width: textW, height: ceil(bodySize.height))
        container.addSubview(bodyLabel)

        let vc = NSViewController()
        vc.view = container
        let pop = NSPopover()
        pop.behavior = .semitransient
        pop.animates = true
        pop.contentSize = NSSize(width: popW, height: popH)
        pop.contentViewController = vc
        pop.show(relativeTo: bounds, of: self, preferredEdge: .maxY)
        hoverPopover = pop
    }

    override func updateLayer() {
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        layer?.backgroundColor = pillColor.withAlphaComponent(dark ? 0.16 : 0.12).cgColor
        layer?.borderColor = pillColor.withAlphaComponent(dark ? 0.32 : 0.24).cgColor
        layer?.borderWidth = 1
        layer?.cornerRadius = frame.height / 2
    }
}

// Slider with a live colorful vertical indicator line drawn right over the track.
private final class MarkedSlider: NSSlider {
    var markerFraction: Double? { didSet { needsDisplay = true } }
    var markerColor: NSColor = .systemGreen { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let frac = markerFraction, let sc = cell as? NSSliderCell else { return }
        let bar = sc.barRect(flipped: isFlipped)
        let x: CGFloat
        if numberOfTickMarks >= 2 {
            let x0 = sc.rectOfTickMark(at: 0).midX
            let x1 = sc.rectOfTickMark(at: numberOfTickMarks - 1).midX
            let rawX = x0 + CGFloat(frac) * (x1 - x0)
            x = min(max(rawX, bar.minX + 1.5), bar.maxX - 1.5)
        } else {
            let rawX = bar.minX + CGFloat(min(max(frac, 0), 1)) * bar.width
            x = min(max(rawX, bar.minX + 1.5), bar.maxX - 1.5)
        }
        let lineW: CGFloat = 2.5
        let lineH: CGFloat = 11.0
        let rect = NSRect(x: x - lineW / 2, y: bar.midY - lineH / 2, width: lineW, height: lineH)
        let pill = NSBezierPath(roundedRect: rect, xRadius: lineW / 2, yRadius: lineW / 2)

        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        (dark ? NSColor.black.withAlphaComponent(0.55) : NSColor.white.withAlphaComponent(0.85)).setStroke()
        pill.lineWidth = 1.6
        pill.stroke()

        markerColor.setFill()
        pill.fill()
    }
}

private func fractionalStopIndex(for value: Double, numericStops: [Int]) -> Double {
    guard !numericStops.isEmpty else { return 0 }
    if value <= Double(numericStops.first!) { return 0 }
    if value >= Double(numericStops.last!) { return Double(numericStops.count - 1) + 0.25 }
    for i in 0..<(numericStops.count - 1) {
        let a = Double(numericStops[i])
        let b = Double(numericStops[i + 1])
        if value >= a && value <= b {
            return Double(i) + (value - a) / max(b - a, 0.001)
        }
    }
    return Double(numericStops.count - 1)
}

// MARK: - 30-Minute Thermal History Sparkline Graph
private final class ThermalGraphView: NSView {
    var samples: [ThermalSample] = [] { didSet { needsDisplay = true } }
    var cutoffTempC: Int = thermalDefaultTemp { didSet { needsDisplay = true } }

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let bounds = self.bounds
        let bgPath = NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8)
        (dark ? NSColor.black.withAlphaComponent(0.24) : NSColor.black.withAlphaComponent(0.045)).setFill()
        bgPath.fill()
        (dark ? NSColor.white.withAlphaComponent(0.07) : NSColor.black.withAlphaComponent(0.06)).setStroke()
        bgPath.lineWidth = 1
        bgPath.stroke()

        let padL: CGFloat = 34
        let padR: CGFloat = 12
        let padT: CGFloat = 12
        let stripH: CGFloat = 4
        let stripY: CGFloat = 19
        let padB: CGFloat = 28
        let plotW = max(bounds.width - padL - padR, 1)
        let plotH = max(bounds.height - padT - padB, 1)

        // Tightly auto-scale vertical axis around observed temperatures + active cutoff threshold.
        let temps = samples.compactMap(\.tempC)
        var allVals = temps
        if cutoffTempC > 0 { allVals.append(Double(cutoffTempC)) }
        let rawMin = allVals.min() ?? 40.0
        let rawMax = allVals.max() ?? 85.0
        var minY = floor(rawMin - 2.0)
        var maxY = ceil(rawMax + 2.0)
        if maxY - minY < 8.0 {
            let mid = (minY + maxY) / 2.0
            minY = floor(mid - 4.0)
            maxY = ceil(mid + 4.0)
        }
        minY = max(0.0, minY)

        func yFor(_ temp: Double) -> CGFloat {
            let clamped = min(max(temp, minY), maxY)
            let norm = (clamped - minY) / max(maxY - minY, 1)
            return padB + CGFloat(norm) * plotH
        }

        // Fixed 30-minute horizontal window (30m ago -> now).
        let now = Date()
        let windowStart = now.addingTimeInterval(-thermalHistoryWindow)
        let validSamples = samples.compactMap { s -> (Date, Double)? in
            guard let t = s.tempC else { return nil }
            return (s.date, t)
        }
        func xFor(_ date: Date) -> CGFloat {
            let elapsed = date.timeIntervalSince(windowStart)
            let norm = min(max(elapsed / thermalHistoryWindow, 0), 1)
            return padL + CGFloat(norm) * plotW
        }

        // Dynamic min/max Y-axis gridlines + subtle midpoint line
        let axisColor = NSColor.secondaryLabelColor.withAlphaComponent(0.75)
        let axisAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular),
            .foregroundColor: axisColor
        ]
        let gridColor = dark ? NSColor.white.withAlphaComponent(0.07) : NSColor.black.withAlphaComponent(0.07)
        for refTemp in [minY, (minY + maxY) / 2.0, maxY] {
            let y = yFor(refTemp)
            let grid = NSBezierPath()
            grid.move(to: NSPoint(x: padL, y: y))
            grid.line(to: NSPoint(x: bounds.width - padR, y: y))
            gridColor.setStroke()
            grid.lineWidth = 0.75
            grid.stroke()
        }
        // Left-side min and max degree labels (right-aligned neatly inside padL)
        let minLbl = "\(Int(minY))°" as NSString
        let minW = minLbl.size(withAttributes: axisAttrs).width
        minLbl.draw(at: NSPoint(x: padL - minW - 6, y: yFor(minY) - 5.5), withAttributes: axisAttrs)
        let maxLbl = "\(Int(maxY))°" as NSString
        let maxW = maxLbl.size(withAttributes: axisAttrs).width
        maxLbl.draw(at: NSPoint(x: padL - maxW - 6, y: yFor(maxY) - 5.5), withAttributes: axisAttrs)

        // X-axis time labels (fixed 30m window, peak center, live temp right)
        ("30m" as NSString).draw(at: NSPoint(x: padL, y: 4), withAttributes: axisAttrs)
        let nowText = temps.last.map { String(format: "now %.0f°C", $0) } ?? "now"
        let nowStr = nowText as NSString
        let nowW = nowStr.size(withAttributes: axisAttrs).width
        nowStr.draw(at: NSPoint(x: bounds.width - padR - nowW, y: 4), withAttributes: axisAttrs)

        // Peak label centered on bottom axis if we have readings
        if let peak = temps.max() {
            let peakStr = String(format: "peak %.0f°C", peak) as NSString
            let pw = peakStr.size(withAttributes: axisAttrs).width
            let centerX = padL + (plotW - pw) / 2
            if centerX + pw + 6 < bounds.width - padR - nowW {
                peakStr.draw(at: NSPoint(x: centerX, y: 4), withAttributes: axisAttrs)
            }
        }

        // macOS ProcessInfo.thermalState timeline strip directly beneath the plot
        let stripBg = NSBezierPath(roundedRect: NSRect(x: padL, y: stripY, width: plotW, height: stripH),
                                   xRadius: 2, yRadius: 2)
        (dark ? NSColor.white.withAlphaComponent(0.06) : NSColor.black.withAlphaComponent(0.06)).setFill()
        stripBg.fill()
        if !samples.isEmpty {
            NSGraphicsContext.saveGraphicsState()
            stripBg.addClip()
            for (idx, s) in samples.enumerated() {
                let x0 = xFor(s.date)
                let x1 = (idx + 1 < samples.count) ? xFor(samples[idx + 1].date) : (padL + plotW)
                let segW = max(x1 - x0, 2.0)
                let (_, stateColor) = thermalDisplay(s.state)
                stateColor.withAlphaComponent(0.75).setFill()
                NSRect(x: x0, y: stripY, width: segW, height: stripH).fill()
            }
            NSGraphicsContext.restoreGraphicsState()
        }

        // Temperature curve + area fill (always consistent brandAccentSoft color)
        if !validSamples.isEmpty {
            let points = validSamples.map { NSPoint(x: xFor($0.0), y: yFor($0.1)) }
            let lineColor = brandAccentSoft

            if points.count >= 2 {
                let line = NSBezierPath()
                line.move(to: points[0])
                for p in points.dropFirst() { line.line(to: p) }

                let area = line.copy() as! NSBezierPath
                area.line(to: NSPoint(x: points.last!.x, y: padB))
                area.line(to: NSPoint(x: points.first!.x, y: padB))
                area.close()
                let grad = NSGradient(starting: lineColor.withAlphaComponent(dark ? 0.28 : 0.20),
                                      ending: lineColor.withAlphaComponent(0.01))
                grad?.draw(in: area, angle: -90)

                lineColor.setStroke()
                line.lineWidth = 1.75
                line.lineJoinStyle = .round
                line.lineCapStyle = .round
                line.stroke()
            }

            // Live dot at latest reading
            let last = points.last!
            let dot = NSBezierPath(ovalIn: NSRect(x: last.x - 2.75, y: last.y - 2.75, width: 5.5, height: 5.5))
            lineColor.setFill()
            dot.fill()
        }

        // Dashed horizontal cutoff threshold line (colored by risk level; no overlapping text tag)
        if cutoffTempC > 0 {
            let riskColor = thermalCutoffRisk(cutoffTempC).color
            let ty = yFor(Double(cutoffTempC))
            let dash = NSBezierPath()
            dash.move(to: NSPoint(x: padL, y: ty))
            dash.line(to: NSPoint(x: bounds.width - padR, y: ty))
            let pattern: [CGFloat] = [4, 3]
            dash.setLineDash(pattern, count: 2, phase: 0)
            riskColor.withAlphaComponent(0.88).setStroke()
            dash.lineWidth = 1.15
            dash.stroke()
        }
    }
}

// MARK: - AppDelegate
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var thermalSampleTimer: Timer?
    private var leaseTimer: Timer?
    private var thermalObserver: NSObjectProtocol?
    private var signalSources: [DispatchSourceSignal] = []
    private let thermalSensor = ThermalSensor()
    private var thermalHistory: [ThermalSample] = []
    private var ownsLidDisable = false       // true when THIS process enabled pmset disablesleep

    private let offGlyph = makeCupGlyph(.off)
    private let awakeGlyph = makeCupGlyph(.awake)
    private let lidClosedGlyph = makeCupGlyph(.lidClosed)
    private let lidArmedGlyph = makeCupGlyph(.lidArmed)

    // Popover UI
    private let popover = NSPopover()
    private var headerMark: NSImageView!
    private var headerTitle: NSTextField!
    private var mainCard: CardView!
    private var masterSwitch: NSSwitch!
    private var lidIcon: NSImageView!
    private var lidLabel: NSTextField!
    private var lidSwitch: NSSwitch!

    // Unified slider controls
    private var timerSlider: NSSlider!
    private var timerValueLabel: NSTextField!

    private var floorSlider: NSSlider!
    private var floorValueLabel: NSTextField!

    private var thermalSlider: MarkedSlider!
    private var thermalLiveBadge: PillBadge!
    private var thermalValueLabel: NSTextField!
    private var thermalStateSlider: MarkedSlider!
    private var thermalStateValueLabel: NSTextField!
    private var thermalGraph: ThermalGraphView!

    private var loginSwitch: NSSwitch!
    private var clickMonitor: Any?

    // State
    private var masterOn = true              // default ON: prevents idle sleep in normal state
    private var lidClosedOn = false          // opt-in: pmset disablesleep (true system state)
    private var sleepAssertionID: IOPMAssertionID = 0
    private var hasSleepAssertion = false

    private var batteryFloorPercent = floorDefault
    private var thermalCutoffTempC = thermalDefaultTemp      // 0 = Off, else 60...95 °C
    private var thermalStateCutoff = thermalStateDefault     // 0 = Off, else 1(Fair)...3(Critical)
    private var userForcedOn = false         // honors deliberate turn-on over LPM auto-off (battery/thermal still win)

    // Auto-off timer (in-memory; dies on quit, never survives a reboot)
    private var autoOffMinutes = 0
    private var keepAwakeTimer: Timer?
    private var countdownTicker: Timer?
    private var timerEndDate: Date?

    private let popoverWidth: CGFloat = 336
    private let popoverHeight: CGFloat = 636

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        batteryFloorPercent = min(max((UserDefaults.standard.object(forKey: floorKey) as? Int) ?? floorDefault, floorMin), floorMax)
        if let saved = UserDefaults.standard.object(forKey: thermalKey) as? Int,
           thermalStopTemps.contains(saved) {
            thermalCutoffTempC = saved
        }
        if let savedState = UserDefaults.standard.object(forKey: thermalStateKey) as? Int,
           thermalStateStops.contains(savedState) {
            thermalStateCutoff = savedState
        }

        // Fixed length prevents the status item from resizing when the cup glyph swaps,
        // which otherwise causes an open NSPopover to jump horizontally.
        statusItem = NSStatusBar.system.statusItem(withLength: 26)
        if let button = statusItem.button {
            button.wantsLayer = true
            button.image = awakeGlyph
            button.action = #selector(statusClicked)
            button.target = self
        }
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.contentSize = NSSize(width: popoverWidth, height: popoverHeight)
        popover.contentViewController = makeContentController()

        // Default ON: prevent idle sleep immediately on launch (unless fail-closed guard blocks it).
        installSignalHandlers()
        recordThermalSample()
        if safetyBlockReason() == nil {
            setIdleAssertion(true)
        } else {
            setIdleAssertion(false)
        }

        refresh()   // sync lid-closed state + enforce safety nets on launch
        timer = Timer.scheduledTimer(timeInterval: pollInterval, target: self,
                                     selector: #selector(poll), userInfo: nil, repeats: true)
        thermalSampleTimer = Timer.scheduledTimer(timeInterval: thermalSampleInterval, target: self,
                                                  selector: #selector(sampleThermalTick), userInfo: nil, repeats: true)
        _ = ProcessInfo.processInfo.thermalState
        thermalObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.recordThermalSample()
                self?.refresh()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        releaseOwnedSleepOnExit()
    }

    // MARK: - Crash Safety: Signal Handlers + Detached 2-Minute Lease Watchdog
    private var leaseFileURL: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Sleepless", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("lid-lease")
    }

    private func installSignalHandlers() {
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig, SIG_IGN)
            let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            src.setEventHandler { [weak self] in
                self?.releaseOwnedSleepOnExit()
                exit(0)
            }
            src.resume()
            signalSources.append(src)
        }
    }

    private func releaseOwnedSleepOnExit() {
        setIdleAssertion(false)
        stopLeaseWatchdog()
        if ownsLidDisable {
            _ = setDisableSleep(false)
            ownsLidDisable = false
        }
    }

    private func writeLeaseTimestamp() {
        let ts = "\(Int(Date().timeIntervalSince1970))\n"
        try? ts.write(to: leaseFileURL, atomically: true, encoding: .utf8)
    }

    private func startLeaseWatchdog() {
        writeLeaseTimestamp()
        if leaseTimer == nil {
            leaseTimer = Timer.scheduledTimer(timeInterval: leaseRefreshInterval, target: self,
                                              selector: #selector(refreshLeaseTick), userInfo: nil, repeats: true)
        }
        // Spawn a user-space watchdog child that outlives the app (no root daemon, no extra sudoers rules).
        // If Sleepless crashes (kill -0 fails) or hangs (>120s stale lease), it restores
        // pmset disablesleep 0 using the existing scoped NOPASSWD grant and exits.
        let pid = ProcessInfo.processInfo.processIdentifier
        let leasePath = leaseFileURL.path
        let script = """
        PID="$1"; LEASE="$2"; MAX_AGE=\(leaseMaxAgeSeconds)
        while [ -f "$LEASE" ]; do
          if ! /bin/kill -0 "$PID" 2>/dev/null; then
            /usr/bin/sudo -n /usr/bin/pmset -a disablesleep 0 >/dev/null 2>&1
            /bin/rm -f "$LEASE"
            exit 0
          fi
          NOW=$(/bin/date +%s)
          TS=$(/bin/cat "$LEASE" 2>/dev/null || echo 0)
          if [ $((NOW - TS)) -gt "$MAX_AGE" ]; then
            /usr/bin/sudo -n /usr/bin/pmset -a disablesleep 0 >/dev/null 2>&1
            /bin/rm -f "$LEASE"
            exit 0
          fi
          /bin/sleep 5
        done
        """
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", script, "sleepless-watchdog", "\(pid)", leasePath]
        proc.standardInput = FileHandle.nullDevice
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        do { try proc.run() }
        catch { NSLog("Sleepless: failed to launch watchdog: %@", error.localizedDescription) }
    }

    @objc private func refreshLeaseTick() {
        guard ownsLidDisable else { stopLeaseWatchdog(); return }
        writeLeaseTimestamp()
    }

    private func stopLeaseWatchdog() {
        leaseTimer?.invalidate(); leaseTimer = nil
        try? FileManager.default.removeItem(at: leaseFileURL)
    }

    // MARK: - Popover UI (Modern Liquid Glass + Unified Slider Cards)
    private func makeContentController() -> NSViewController {
        let W = popoverWidth
        let pad: CGFloat = 14
        let contentW = W - pad * 2
        let ci: CGFloat = 12
        let cw = contentW - ci * 2

        let root = GlassView(frame: NSRect(x: 0, y: 0, width: W, height: popoverHeight))
        root.material = .popover
        root.blendingMode = .behindWindow
        root.state = .followsWindowActiveState

        // Header
        let mark = NSImageView(frame: NSRect(x: pad + 2, y: 13, width: 20, height: 20))
        mark.imageScaling = .scaleProportionallyDown
        root.addSubview(mark)
        headerMark = mark

        let title = makeLabel("Sleepless", font: .systemFont(ofSize: 14, weight: .semibold), color: .labelColor)
        title.frame = NSRect(x: pad + 28, y: 14, width: 160, height: 20)
        root.addSubview(title)
        headerTitle = title

        func makeCard(_ rect: NSRect) -> CardView {
            let c = CardView(frame: rect)
            c.wantsLayer = true
            root.addSubview(c)
            return c
        }

        func makeIcon(_ symbol: String, color: NSColor = .secondaryLabelColor) -> NSImageView {
            let iv = NSImageView()
            let cfg = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            let img = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(cfg)
            img?.isTemplate = true
            iv.image = img
            iv.contentTintColor = color
            iv.imageAlignment = .alignCenter
            return iv
        }

        let swProto = NSSwitch().intrinsicContentSize
        let swW = swProto.width > 0 ? swProto.width : 38
        let swH = swProto.height > 0 ? swProto.height : 21

        // CARD 1 — Hero Sleep Controls (Master toggle + Lid-closed toggle, no subtitles)
        let g1y: CGFloat = 44, g1h: CGFloat = 86
        let g1 = makeCard(NSRect(x: pad, y: g1y, width: contentW, height: g1h))
        mainCard = g1

        let masterIcon = makeIcon("bolt.fill", color: brandAccentSoft)
        masterIcon.frame = NSRect(x: ci, y: 12, width: 16, height: 18)
        g1.addSubview(masterIcon)

        let masterLabel = makeLabel("Keep Mac awake", font: .systemFont(ofSize: 13, weight: .semibold), color: .labelColor)
        masterLabel.frame = NSRect(x: ci + 22, y: 11, width: cw - swW - 28, height: 20)
        g1.addSubview(masterLabel)

        masterSwitch = NSSwitch()
        masterSwitch.target = self
        masterSwitch.action = #selector(masterSwitchToggled(_:))
        masterSwitch.frame = NSRect(x: contentW - ci - swW, y: 11 + (20 - swH) / 2, width: swW, height: swH)
        g1.addSubview(masterSwitch)

        let divider = HairlineView(frame: NSRect(x: ci, y: 43, width: cw, height: 1))
        divider.wantsLayer = true
        g1.addSubview(divider)

        lidIcon = makeIcon("macbook", color: .secondaryLabelColor)
        lidIcon.frame = NSRect(x: ci, y: 55, width: 16, height: 18)
        g1.addSubview(lidIcon)

        lidLabel = makeLabel("Allow lid closed", font: .systemFont(ofSize: 13, weight: .medium), color: .labelColor)
        lidLabel.frame = NSRect(x: ci + 22, y: 54, width: cw - swW - 28, height: 20)
        g1.addSubview(lidLabel)

        lidSwitch = NSSwitch()
        lidSwitch.target = self
        lidSwitch.action = #selector(lidSwitchToggled(_:))
        lidSwitch.frame = NSRect(x: contentW - ci - swW, y: 54 + (20 - swH) / 2, width: swW, height: swH)
        g1.addSubview(lidSwitch)

        // CARD 2 — Auto-off timer (unified slider)
        let g2y = g1y + g1h + 10, g2h: CGFloat = 80
        let g2 = makeCard(NSRect(x: pad, y: g2y, width: contentW, height: g2h))

        let timerIcon = makeIcon("timer", color: .secondaryLabelColor)
        timerIcon.frame = NSRect(x: ci, y: ci + 1, width: 16, height: 16)
        g2.addSubview(timerIcon)

        let timerTitle = makeLabel("Auto-off timer", font: .systemFont(ofSize: 13, weight: .medium), color: .labelColor)
        timerTitle.frame = NSRect(x: ci + 22, y: ci, width: cw - 110, height: 18)
        g2.addSubview(timerTitle)

        timerValueLabel = makeLabel("Off", font: .monospacedDigitSystemFont(ofSize: 12.5, weight: .semibold), color: .secondaryLabelColor)
        timerValueLabel.alignment = .right
        timerValueLabel.frame = NSRect(x: contentW - ci - 90, y: ci, width: 90, height: 18)
        g2.addSubview(timerValueLabel)

        timerSlider = NSSlider(value: 0, minValue: 0, maxValue: Double(timerStopMinutes.count - 1),
                               target: self, action: #selector(timerSliderChanged(_:)))
        timerSlider.numberOfTickMarks = timerStopMinutes.count
        timerSlider.allowsTickMarkValuesOnly = true
        timerSlider.isContinuous = true
        timerSlider.controlSize = .small
        timerSlider.frame = NSRect(x: ci, y: ci + 24, width: cw, height: 20)
        g2.addSubview(timerSlider)

        let timerMin = makeLabel("Off", font: .systemFont(ofSize: 10), color: .tertiaryLabelColor)
        timerMin.frame = NSRect(x: ci, y: ci + 46, width: 32, height: 13)
        g2.addSubview(timerMin)

        let timerMax = makeLabel("8h", font: .systemFont(ofSize: 10), color: .tertiaryLabelColor)
        timerMax.alignment = .right
        timerMax.frame = NSRect(x: contentW - ci - 32, y: ci + 46, width: 32, height: 13)
        g2.addSubview(timerMax)

        // CARD 3 — Low battery cutoff (unified slider)
        let g3y = g2y + g2h + 10, g3h: CGFloat = 80
        let g3 = makeCard(NSRect(x: pad, y: g3y, width: contentW, height: g3h))

        let battIcon = makeIcon("battery.25", color: .secondaryLabelColor)
        battIcon.frame = NSRect(x: ci, y: ci + 1, width: 16, height: 16)
        g3.addSubview(battIcon)

        let floorTitle = makeLabel("Low battery cutoff", font: .systemFont(ofSize: 13, weight: .medium), color: .labelColor)
        floorTitle.frame = NSRect(x: ci + 22, y: ci, width: cw - 80, height: 18)
        g3.addSubview(floorTitle)

        floorValueLabel = makeLabel("\(batteryFloorPercent)%", font: .monospacedDigitSystemFont(ofSize: 12.5, weight: .semibold), color: .secondaryLabelColor)
        floorValueLabel.alignment = .right
        floorValueLabel.frame = NSRect(x: contentW - ci - 56, y: ci, width: 56, height: 18)
        g3.addSubview(floorValueLabel)

        floorSlider = NSSlider(value: Double(batteryFloorPercent), minValue: Double(floorMin), maxValue: Double(floorMax),
                               target: self, action: #selector(floorSliderChanged(_:)))
        floorSlider.isContinuous = true
        floorSlider.controlSize = .small
        floorSlider.frame = NSRect(x: ci, y: ci + 24, width: cw, height: 20)
        g3.addSubview(floorSlider)

        let minHint = makeLabel("\(floorMin)%", font: .systemFont(ofSize: 10), color: .tertiaryLabelColor)
        minHint.frame = NSRect(x: ci, y: ci + 46, width: 34, height: 13)
        g3.addSubview(minHint)

        let maxHint = makeLabel("\(floorMax)%", font: .systemFont(ofSize: 10), color: .tertiaryLabelColor)
        maxHint.alignment = .right
        maxHint.frame = NSRect(x: contentW - ci - 34, y: ci + 46, width: 34, height: 13)
        g3.addSubview(maxHint)

        // CARD 4 — Thermal protection (unified warning pill + 30m graph + SoC & macOS thermalState sliders)
        let g4y = g3y + g3h + 10, g4h: CGFloat = 264
        let g4 = makeCard(NSRect(x: pad, y: g4y, width: contentW, height: g4h))

        let thermIcon = makeIcon("thermometer.medium", color: .secondaryLabelColor)
        thermIcon.frame = NSRect(x: ci, y: ci + 1, width: 16, height: 16)
        g4.addSubview(thermIcon)

        let thermTitle = makeLabel("Thermal protection", font: .systemFont(ofSize: 13, weight: .medium), color: .labelColor)
        thermTitle.frame = NSRect(x: ci + 22, y: ci, width: 132, height: 18)
        g4.addSubview(thermTitle)

        thermalLiveBadge = PillBadge(frame: NSRect(x: contentW - ci - 116, y: ci - 1, width: 116, height: 20))
        thermalLiveBadge.hoverTitle = "Your responsibility"
        thermalLiveBadge.hoverMessage = "Thermal cutoffs are a best-effort safety net, not a guarantee. Keeping your Mac awake—especially with the lid closed—can trap heat and wear the battery or display. You are responsible for ventilation, never running lid-closed in a bag or on soft surfaces, and choosing safe limits."
        g4.addSubview(thermalLiveBadge)

        thermalGraph = ThermalGraphView(frame: NSRect(x: ci, y: ci + 28, width: cw, height: 96))
        thermalGraph.cutoffTempC = thermalCutoffTempC
        g4.addSubview(thermalGraph)

        let thermDivider = HairlineView(frame: NSRect(x: ci, y: ci + 132, width: cw, height: 1))
        thermDivider.wantsLayer = true
        g4.addSubview(thermDivider)

        // Slider 1: SoC die temperature cutoff
        let s1y = ci + 140
        let socLbl = makeLabel("SoC limit", font: .systemFont(ofSize: 11.5, weight: .medium), color: .secondaryLabelColor)
        socLbl.frame = NSRect(x: ci, y: s1y, width: 120, height: 15)
        g4.addSubview(socLbl)

        thermalValueLabel = makeLabel("", font: .monospacedDigitSystemFont(ofSize: 11.5, weight: .semibold), color: .secondaryLabelColor)
        thermalValueLabel.alignment = .right
        thermalValueLabel.frame = NSRect(x: contentW - ci - 90, y: s1y, width: 90, height: 15)
        g4.addSubview(thermalValueLabel)

        let thermIdx = thermalStopTemps.firstIndex(of: thermalCutoffTempC) ?? 4
        thermalSlider = MarkedSlider(value: Double(thermIdx), minValue: 0,
                                     maxValue: Double(thermalStopTemps.count - 1),
                                     target: self, action: #selector(thermalSliderChanged(_:)))
        thermalSlider.numberOfTickMarks = thermalStopTemps.count
        thermalSlider.allowsTickMarkValuesOnly = true
        thermalSlider.isContinuous = true
        thermalSlider.controlSize = .small
        thermalSlider.frame = NSRect(x: ci, y: s1y + 17, width: cw, height: 18)
        g4.addSubview(thermalSlider)

        let thermMin = makeLabel("60°C", font: .systemFont(ofSize: 9.5), color: .tertiaryLabelColor)
        thermMin.frame = NSRect(x: ci, y: s1y + 36, width: 34, height: 12)
        g4.addSubview(thermMin)

        let thermMax = makeLabel("Off", font: .systemFont(ofSize: 9.5), color: .tertiaryLabelColor)
        thermMax.alignment = .right
        thermMax.frame = NSRect(x: contentW - ci - 30, y: s1y + 36, width: 30, height: 12)
        g4.addSubview(thermMax)

        // Slider 2: macOS thermalState cutoff
        let s2y = s1y + 54
        let stateLbl = makeLabel("macOS thermalState", font: .systemFont(ofSize: 11.5, weight: .medium), color: .secondaryLabelColor)
        stateLbl.frame = NSRect(x: ci, y: s2y, width: 140, height: 15)
        g4.addSubview(stateLbl)

        thermalStateValueLabel = makeLabel("", font: .systemFont(ofSize: 11.5, weight: .semibold), color: .secondaryLabelColor)
        thermalStateValueLabel.alignment = .right
        thermalStateValueLabel.frame = NSRect(x: contentW - ci - 90, y: s2y, width: 90, height: 15)
        g4.addSubview(thermalStateValueLabel)

        let stateIdx = thermalStateStops.firstIndex(of: thermalStateCutoff) ?? 1
        thermalStateSlider = MarkedSlider(value: Double(stateIdx), minValue: 0,
                                          maxValue: Double(thermalStateStops.count - 1),
                                          target: self, action: #selector(thermalStateSliderChanged(_:)))
        thermalStateSlider.numberOfTickMarks = thermalStateStops.count
        thermalStateSlider.allowsTickMarkValuesOnly = true
        thermalStateSlider.isContinuous = true
        thermalStateSlider.controlSize = .small
        thermalStateSlider.frame = NSRect(x: ci, y: s2y + 17, width: cw, height: 18)
        g4.addSubview(thermalStateSlider)

        let stateMin = makeLabel("Fair", font: .systemFont(ofSize: 9.5), color: .tertiaryLabelColor)
        stateMin.frame = NSRect(x: ci, y: s2y + 36, width: 34, height: 12)
        g4.addSubview(stateMin)

        let stateMax = makeLabel("Off", font: .systemFont(ofSize: 9.5), color: .tertiaryLabelColor)
        stateMax.alignment = .right
        stateMax.frame = NSRect(x: contentW - ci - 30, y: s2y + 36, width: 30, height: 12)
        g4.addSubview(stateMax)

        // FOOTER — Clean borderless utility bar (Launch at login on left, quiet Quit on right)
        let fy = g4y + g4h + 10, fh: CGFloat = 32
        let loginIcon = makeIcon("arrow.triangle.2.circlepath", color: .tertiaryLabelColor)
        loginIcon.frame = NSRect(x: pad + 4, y: fy + 8, width: 15, height: 15)
        root.addSubview(loginIcon)

        let loginLabel = makeLabel("Launch at login", font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        loginLabel.frame = NSRect(x: pad + 24, y: fy + 7, width: 96, height: 17)
        root.addSubview(loginLabel)

        loginSwitch = NSSwitch()
        loginSwitch.controlSize = .mini
        loginSwitch.target = self
        loginSwitch.action = #selector(loginToggled(_:))
        loginSwitch.state = loginItemEnabled() ? .on : .off
        let ssw = loginSwitch.intrinsicContentSize
        let sW = ssw.width > 0 ? ssw.width : 26
        let sH = ssw.height > 0 ? ssw.height : 15
        loginSwitch.frame = NSRect(x: pad + 122, y: fy + (fh - sH) / 2, width: sW, height: sH)
        root.addSubview(loginSwitch)

        let quit = NSButton(title: "Quit", target: self, action: #selector(quit))
        quit.isBordered = false
        quit.font = .systemFont(ofSize: 12, weight: .medium)
        quit.contentTintColor = .secondaryLabelColor
        if let pImg = NSImage(systemSymbolName: "power", accessibilityDescription: "Quit")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)) {
            pImg.isTemplate = true
            quit.image = pImg
            quit.imagePosition = .imageLeading
        }
        quit.sizeToFit()
        let qs = quit.frame.size
        quit.frame = NSRect(x: W - pad - qs.width - 4, y: fy + (fh - qs.height) / 2,
                            width: qs.width + 4, height: qs.height)
        root.addSubview(quit)

        let vc = NSViewController()
        vc.view = root
        return vc
    }

    private func makeLabel(_ s: String, font: NSFont, color: NSColor) -> NSTextField {
        let t = NSTextField(labelWithString: s)
        t.font = font
        t.textColor = color
        t.isEditable = false
        t.isBordered = false
        t.drawsBackground = false
        return t
    }

    // MARK: - Popover lifecycle
    @objc private func statusClicked() {
        if popover.isShown { closePopover() } else { openPopover() }
    }

    private func openPopover() {
        refresh()
        loginSwitch?.state = loginItemEnabled() ? .on : .off
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        if keepAwakeTimer != nil { startCountdownTicker() }
        updateTimerLabels()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func closePopover() {
        thermalLiveBadge?.dismissHoverPopover()
        popover.performClose(nil)
        countdownTicker?.invalidate(); countdownTicker = nil
        if let monitor = clickMonitor { NSEvent.removeMonitor(monitor); clickMonitor = nil }
    }

    // MARK: - IOKit Idle Sleep Assertion (Master toggle — no root needed)
    private func setIdleAssertion(_ on: Bool) {
        if on {
            guard !hasSleepAssertion else { masterOn = true; return }
            let reason = "Sleepless keeping Mac awake" as CFString
            let type = kIOPMAssertionTypePreventUserIdleSystemSleep as CFString
            let kr = IOPMAssertionCreateWithName(type, IOPMAssertionLevel(kIOPMAssertionLevelOn), reason, &sleepAssertionID)
            if kr == kIOReturnSuccess {
                hasSleepAssertion = true
                masterOn = true
            } else {
                NSLog("Sleepless: IOPMAssertionCreateWithName failed: %d", kr)
                masterOn = false
            }
        } else {
            if hasSleepAssertion {
                IOPMAssertionRelease(sleepAssertionID)
                sleepAssertionID = 0
                hasSleepAssertion = false
            }
            masterOn = false
        }
    }

    // MARK: - Toggle Actions
    @objc private func masterSwitchToggled(_ sender: NSSwitch) {
        let wantOn = sender.state == .on
        if wantOn {
            // Fail-closed pre-start guard: refuse to turn on if thermal or battery limit is already tripped.
            if let reason = safetyBlockReason() {
                sender.state = .off
                notify("Can't stay awake: \(reason)")
                return
            }
            UserDefaults.standard.removeObject(forKey: lastStopKey)
            setIdleAssertion(true)
            userForcedOn = true
            refresh()
            if anyAwake, autoOffMinutes > 0 { startKeepAwakeTimer(minutes: autoOffMinutes) }
        } else {
            // Turning master OFF also turns off lid-closed sleep prevention.
            setIdleAssertion(false)
            if lidClosedOn || ownsLidDisable {
                _ = setDisableSleep(false)
                ownsLidDisable = false
                stopLeaseWatchdog()
            }
            userForcedOn = false
            cancelKeepAwakeTimer()
            refresh()
        }
    }

    @objc private func lidSwitchToggled(_ sender: NSSwitch) {
        if performLidToggle(wantOn: sender.state == .on) {
            sender.state = .off
        }
    }

    @discardableResult
    private func performLidToggle(wantOn: Bool) -> Bool {
        if wantOn, let reason = safetyBlockReason() {
            notify("Can't keep awake with lid closed: \(reason)")
            return true
        }
        var result = setDisableSleep(wantOn)
        if wantOn, result == .grantMissing {
            if installGrantViaAuth() { result = setDisableSleep(true) }
            if result != .ok {
                notify("Couldn't keep awake with lid closed. The permission isn't set up yet.")
                return true
            }
        }
        if wantOn, result == .ok {
            UserDefaults.standard.removeObject(forKey: lastStopKey)
            ownsLidDisable = true
            startLeaseWatchdog()
            setIdleAssertion(true)
            userForcedOn = true
        } else if !wantOn, result == .ok {
            ownsLidDisable = false
            stopLeaseWatchdog()
        }
        refresh()
        if anyAwake, autoOffMinutes > 0, keepAwakeTimer == nil {
            startKeepAwakeTimer(minutes: autoOffMinutes)
        }
        return false
    }

    private var anyAwake: Bool { masterOn || lidClosedOn }

    private func turnEverythingOff(reason: String? = nil) {
        setIdleAssertion(false)
        if ownsLidDisable || readSleepDisabled() { _ = setDisableSleep(false) }
        ownsLidDisable = false
        stopLeaseWatchdog()
        userForcedOn = false
        cancelKeepAwakeTimer()
        if let reason {
            UserDefaults.standard.set(reason, forKey: lastStopKey)
        }
        applyUI(lidOn: readSleepDisabled())
    }

    // MARK: - One-time Native Auth Grant (unchanged security model)
    @discardableResult
    private func installGrantViaAuth() -> Bool {
        let intro = NSAlert()
        intro.alertStyle = .informational
        intro.messageText = "Enable keeping your Mac awake with lid closed"
        intro.informativeText = "Sleepless flips a protected macOS setting (pmset disablesleep), so it needs your permission once. macOS will ask you to authenticate (Touch ID or your password). After that the switch works instantly, with no more prompts."
        intro.addButton(withTitle: "Enable")
        intro.addButton(withTitle: "Not now")
        NSApp.activate(ignoringOtherApps: true)
        guard intro.runModal() == .alertFirstButtonReturn else { return false }

        guard let res = Bundle.main.resourcePath else { return false }
        let grant = res + "/grant.sh"
        let shellCmd = "SLEEPLESS_USER='\(NSUserName())' /bin/bash '\(grant)' --yes"
        let escaped = shellCmd.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let osa = "do shell script \"\(escaped)\" with administrator privileges"
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", osa]
        proc.standardOutput = Pipe(); proc.standardError = Pipe()
        do { try proc.run(); proc.waitUntilExit() }
        catch { notify("Couldn't start the one-time setup."); return false }
        if proc.terminationStatus == 0 { return true }
        if proc.terminationStatus != 128 {
            notify("Setup didn't complete. Try again, or run grant.sh from the app bundle.")
        }
        return false
    }

    private func pulseStatusItem() {
        guard let b = statusItem.button else { return }
        b.wantsLayer = true
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 0.3
        pulse.toValue = 1.0
        pulse.duration = 0.34
        pulse.timingFunction = CAMediaTimingFunction(name: .easeOut)
        b.layer?.add(pulse, forKey: "statePulse")
    }

    @objc private func poll() { refresh() }

    @objc private func sampleThermalTick() {
        let sensor = thermalSensor
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let tempC = sensor.readSmoothedCelsius(count: 5, spacingMs: 20)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.appendThermalSample(tempC: tempC)
                if self.popover.isShown { self.renderThermalUI() }
                if self.anyAwake { self.enforceSafetyNets() }
            }
        }
    }

    private func recordThermalSample() {
        appendThermalSample(tempC: thermalSensor.readSmoothedCelsius(count: 5, spacingMs: 20))
    }

    private func appendThermalSample(tempC: Double?) {
        let now = Date()
        let state = ProcessInfo.processInfo.thermalState
        thermalHistory.append(ThermalSample(date: now, tempC: tempC, state: state))
        let cutoffDate = now.addingTimeInterval(-thermalHistoryWindow)
        if let firstValid = thermalHistory.firstIndex(where: { $0.date >= cutoffDate }), firstValid > 0 {
            thermalHistory.removeFirst(firstValid)
        }
    }

    // MARK: - Unified Slider Actions
    @objc private func timerSliderChanged(_ sender: NSSlider) {
        let idx = min(max(Int(sender.doubleValue.rounded()), 0), timerStopMinutes.count - 1)
        let newMinutes = timerStopMinutes[idx]
        if newMinutes != autoOffMinutes {
            autoOffMinutes = newMinutes
            if anyAwake, autoOffMinutes > 0 {
                startKeepAwakeTimer(minutes: autoOffMinutes)
            } else {
                cancelKeepAwakeTimer()
            }
        }
        updateTimerLabels()
    }

    @objc private func floorSliderChanged(_ sender: NSSlider) {
        let v = min(max(Int(sender.doubleValue.rounded()), floorMin), floorMax)
        if v != batteryFloorPercent {
            batteryFloorPercent = v
            UserDefaults.standard.set(v, forKey: floorKey)
        }
        renderText()
    }

    @objc private func thermalSliderChanged(_ sender: NSSlider) {
        let idx = min(max(Int(sender.doubleValue.rounded()), 0), thermalStopTemps.count - 1)
        let next = thermalStopTemps[idx]
        if next != thermalCutoffTempC {
            thermalCutoffTempC = next
            UserDefaults.standard.set(next, forKey: thermalKey)
            renderThermalUI()
            if anyAwake { enforceSafetyNets() }
        }
    }

    @objc private func thermalStateSliderChanged(_ sender: NSSlider) {
        let idx = min(max(Int(sender.doubleValue.rounded()), 0), thermalStateStops.count - 1)
        let next = thermalStateStops[idx]
        if next != thermalStateCutoff {
            thermalStateCutoff = next
            UserDefaults.standard.set(next, forKey: thermalStateKey)
            renderThermalUI()
            if anyAwake { enforceSafetyNets() }
        }
    }

    // MARK: - Auto-off Timer
    private func startKeepAwakeTimer(minutes: Int) {
        cancelKeepAwakeTimer()
        guard minutes > 0, anyAwake else { updateTimerLabels(); return }
        let seconds = TimeInterval(minutes * 60)
        timerEndDate = Date().addingTimeInterval(seconds)
        keepAwakeTimer = Timer.scheduledTimer(timeInterval: seconds, target: self,
                                              selector: #selector(keepAwakeTimerFired), userInfo: nil, repeats: false)
        if popover.isShown { startCountdownTicker() }
        updateTimerLabels()
    }

    private func cancelKeepAwakeTimer() {
        keepAwakeTimer?.invalidate(); keepAwakeTimer = nil
        countdownTicker?.invalidate(); countdownTicker = nil
        timerEndDate = nil
    }

    @objc private func keepAwakeTimerFired() {
        autoOffMinutes = 0
        timerSlider?.doubleValue = 0
        let msg = "Auto-off timer ended. Sleepless turned off."
        turnEverythingOff(reason: msg)
        notify(msg)
    }

    private func startCountdownTicker() {
        countdownTicker?.invalidate()
        countdownTicker = Timer.scheduledTimer(timeInterval: 1, target: self,
                                               selector: #selector(countdownTick), userInfo: nil, repeats: true)
    }

    @objc private func countdownTick() { updateTimerLabels() }

    private func updateTimerLabels() {
        let idx = timerStopMinutes.firstIndex(of: autoOffMinutes) ?? 0
        let presetText = timerStopLabels[idx]
        if let end = timerEndDate, anyAwake {
            let remaining = Int(end.timeIntervalSinceNow.rounded())
            if remaining > 0 {
                let h = remaining / 3600, m = (remaining % 3600) / 60, s = remaining % 60
                let t = h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
                timerValueLabel?.stringValue = t
                timerValueLabel?.textColor = brandAccentSoft
                return
            }
        }
        timerValueLabel?.stringValue = presetText
        timerValueLabel?.textColor = (autoOffMinutes > 0) ? .labelColor : .secondaryLabelColor
    }

    // MARK: - Launch at Login
    @objc private func loginToggled(_ sender: NSSwitch) {
        do {
            if sender.state == .on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Sleepless: login item update failed: %@", error.localizedDescription)
            notify("Couldn't update Launch at login.")
        }
        sender.state = loginItemEnabled() ? .on : .off
    }

    private func loginItemEnabled() -> Bool { SMAppService.mainApp.status == .enabled }

    // MARK: - Core State Sync
    @objc private func refresh() {
        let lidOn = readSleepDisabled()
        if lidOn && !masterOn { setIdleAssertion(true) }
        applyUI(lidOn: lidOn)
        if anyAwake { enforceSafetyNets() }
    }

    private func applyUI(lidOn: Bool) {
        lidClosedOn = lidOn
        if !anyAwake { cancelKeepAwakeTimer() }

        let (onBattery, discharging, percent) = batteryStatus()
        let armed = lidOn && onBattery && discharging

        if let button = statusItem.button {
            let newImage: NSImage
            if lidOn {
                newImage = armed ? lidArmedGlyph : lidClosedGlyph
            } else if masterOn {
                newImage = awakeGlyph
            } else {
                newImage = offGlyph
            }
            if button.image !== newImage {
                button.image = newImage
                if !popover.isShown { pulseStatusItem() }
            }
            button.alphaValue = anyAwake ? 1.0 : 0.42
            let thermTag = thermalCutoffTempC > 0 ? "\(thermalCutoffTempC)°C" : "Off"
            let pctText = percent.map { "\($0)%" } ?? "?%"
            if lidOn {
                button.toolTip = armed
                    ? "Sleepless: lid-closed on battery (\(pctText)). Auto-off at \(batteryFloorPercent)% or \(thermTag)."
                    : "Sleepless: awake with lid closed. Thermal cutoff: \(thermTag)."
            } else if masterOn {
                button.toolTip = "Sleepless: preventing idle sleep. Thermal cutoff: \(thermTag)."
            } else if let lastStop = UserDefaults.standard.string(forKey: lastStopKey) {
                button.toolTip = "Sleepless: off. Last stop: \(lastStop)"
            } else {
                button.toolTip = "Sleepless: off. Mac sleeps normally."
            }
        }

        masterSwitch?.state = masterOn ? .on : .off
        lidSwitch?.state = lidOn ? .on : .off

        // Pronounced coffee icon when awake; grayed out when disabled.
        if lidOn {
            mainCard?.highlight = .strong
            headerMark?.image = lidClosedGlyph
            headerMark?.contentTintColor = brandAccent
            headerMark?.alphaValue = 1.0
            headerTitle?.textColor = .labelColor
        } else if masterOn {
            mainCard?.highlight = .subtle
            headerMark?.image = awakeGlyph
            headerMark?.contentTintColor = brandAccentSoft
            headerMark?.alphaValue = 1.0
            headerTitle?.textColor = .labelColor
        } else {
            mainCard?.highlight = .none
            headerMark?.image = offGlyph
            headerMark?.contentTintColor = .tertiaryLabelColor
            headerMark?.alphaValue = 0.5
            headerTitle?.textColor = .secondaryLabelColor
        }

        lidIcon?.contentTintColor = lidOn ? brandAccentSoft : .secondaryLabelColor
        lidLabel?.alphaValue = masterOn ? 1.0 : 0.6

        renderText()
        renderThermalUI()
        updateTimerLabels()
    }

    private func renderText() {
        floorValueLabel?.stringValue = "\(batteryFloorPercent)%"
    }

    private func renderThermalUI() {
        let contentW = popoverWidth - 28
        let (riskLabel, riskColor) = thermalCutoffRisk(thermalCutoffTempC)
        let iconName = (thermalCutoffTempC == 0 || thermalCutoffTempC > 80)
            ? "exclamationmark.triangle.fill"
            : "info.circle"
        thermalLiveBadge?.configure(text: riskLabel, color: riskColor, showDot: true, trailingSymbol: iconName)
        if let badge = thermalLiveBadge {
            badge.frame.origin = NSPoint(x: contentW - 12 - badge.frame.width, y: 11)
        }

        thermalValueLabel?.stringValue = thermalCutoffTempC > 0 ? "\(thermalCutoffTempC)°C" : "Off"
        thermalValueLabel?.textColor = riskColor

        let (stateStopLabel, stateStopColor) = thermalStateStopDisplay(thermalStateCutoff)
        thermalStateValueLabel?.stringValue = thermalStateCutoff > 0 ? "≥ \(stateStopLabel)" : "Off"
        thermalStateValueLabel?.textColor = stateStopColor

        // Live vertical indicator lines directly on each slider track
        // Temperature always uses a single consistent color (brandAccentSoft).
        if let soc = thermalHistory.last?.tempC {
            let numericStops = thermalStopTemps.filter { $0 > 0 }
            let idx = fractionalStopIndex(for: soc, numericStops: numericStops)
            thermalSlider?.markerFraction = idx / Double(thermalStopTemps.count - 1)
            thermalSlider?.markerColor = brandAccentSoft
        } else {
            thermalSlider?.markerFraction = nil
        }

        let liveState = ProcessInfo.processInfo.thermalState
        let (_, liveStateColor) = thermalDisplay(liveState)
        let stateFrac: Double
        switch liveState {
        case .nominal:  stateFrac = -0.06
        case .fair:     stateFrac = 0.0 / Double(thermalStateStops.count - 1)
        case .serious:  stateFrac = 1.0 / Double(thermalStateStops.count - 1)
        case .critical: stateFrac = 2.0 / Double(thermalStateStops.count - 1)
        @unknown default: stateFrac = -0.06
        }
        thermalStateSlider?.markerFraction = stateFrac
        thermalStateSlider?.markerColor = liveStateColor

        thermalGraph?.cutoffTempC = thermalCutoffTempC
        thermalGraph?.samples = thermalHistory
    }

    // MARK: - Privileged pmset Control
    private enum ToggleResult: Equatable { case ok, grantMissing, failed(String) }

    @discardableResult
    private func setDisableSleep(_ on: Bool) -> ToggleResult {
        let (exit, _, err) = runPrivileged(["-n", "/usr/bin/pmset", "-a", "disablesleep", on ? "1" : "0"])
        if exit == 0 { return .ok }
        if err.range(of: "a password is required", options: .caseInsensitive) != nil
        || err.range(of: "not allowed", options: .caseInsensitive) != nil
        || err.range(of: "may not run", options: .caseInsensitive) != nil {
            return .grantMissing
        }
        return .failed(err.isEmpty ? "exit \(exit)" : err.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func runPrivileged(_ args: [String]) -> (exit: Int32, out: String, err: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = args
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
        env["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
        process.environment = env
        let outPipe = Pipe(), errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        process.standardInput = FileHandle.nullDevice
        do { try process.run() }
        catch {
            NSLog("Sleepless: failed to launch sudo: %@", error.localizedDescription)
            return (-1, "", "launch failed: \(error.localizedDescription)")
        }
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus,
                String(data: outData, encoding: .utf8) ?? "",
                String(data: errData, encoding: .utf8) ?? "")
    }

    // MARK: - Thermal + Battery + Low-Power-Mode Safety Nets
    private func safetyBlockReason() -> String? {
        let state = ProcessInfo.processInfo.thermalState
        let socTempC = thermalHistory.last?.tempC ?? thermalSensor.readCelsius()

        // 1. CPU temperature guard (AC or battery). If the sensor can't be read, fall back
        //    to blocking at macOS thermalState Serious or worse.
        if thermalCutoffTempC > 0 {
            if let socTempC, socTempC >= Double(thermalCutoffTempC) {
                return String(format: "SoC reached %.0f°C (limit %d°C).", socTempC, thermalCutoffTempC)
            }
            if socTempC == nil {
                switch state {
                case .nominal, .fair: break
                case .serious: return "Mac thermal state is Serious."
                case .critical: return "Mac thermal state is Critical."
                @unknown default: return "Thermal state could not be read."
                }
            }
        }
        // 2. macOS ProcessInfo.thermalState guard.
        if thermalStateCutoff > 0 && state.rawValue >= thermalStateCutoff {
            let (stateName, _) = thermalDisplay(state)
            let (limitName, _) = thermalStateStopDisplay(thermalStateCutoff)
            return "macOS thermal state is \(stateName) (limit \(limitName))."
        }
        // 3. Hard battery floor (fail-closed if battery percent is unreadable while discharging).
        let (onBattery, discharging, percent) = batteryStatus()
        if onBattery && discharging {
            guard let percent else {
                return "Battery level could not be read."
            }
            if percent <= batteryFloorPercent {
                return "Battery low (\(percent)%)."
            }
        }
        return nil
    }

    private func enforceSafetyNets() {
        if let reason = safetyBlockReason() {
            let msg = "\(reason) Sleepless turned off."
            turnEverythingOff(reason: msg)
            notify(msg)
            return
        }
        let (onBattery, discharging, _) = batteryStatus()
        guard onBattery, discharging else { return }
        // 3. Low Power Mode auto-off, unless user deliberately forced awake this session.
        if ProcessInfo.processInfo.isLowPowerModeEnabled && !userForcedOn {
            let msg = "Low Power Mode on. Sleepless turned off."
            turnEverythingOff(reason: msg)
            notify(msg)
        }
    }

    // MARK: - Readers (no root needed)
    private func readSleepDisabled() -> Bool {
        let out = runCapture("/usr/bin/pmset", ["-g"])
        for line in out.split(whereSeparator: { $0 == "\n" }) {
            if line.range(of: "SleepDisabled", options: .caseInsensitive) != nil {
                let toks = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
                if let last = toks.last { return last == "1" }
            }
        }
        return false
    }

    private func batteryStatus() -> (onBattery: Bool, discharging: Bool, percent: Int?) {
        let out = runCapture("/usr/bin/pmset", ["-g", "batt"])
        let onBattery = out.contains("Battery Power")
        let discharging = out.range(of: "discharging", options: .caseInsensitive) != nil
        var percent: Int? = nil
        for tok in out.split(whereSeparator: { " \t\n;".contains($0) }) {
            if tok.hasSuffix("%"), let v = Int(tok.dropLast()) { percent = v; break }
        }
        return (onBattery, discharging, percent)
    }

    private func notify(_ message: String) {
        let script = "display notification \"\(message)\" with title \"Sleepless\" sound name \"Tink\""
        _ = runCapture("/usr/bin/osascript", ["-e", script])
    }

    @discardableResult
    private func runCapture(_ launchPath: String, _ args: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = args
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
        env["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
        process.environment = env
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do { try process.run() }
        catch { NSLog("Sleepless: failed to launch %@: %@", launchPath, error.localizedDescription); return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

@main
enum SleeplessApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        objc_setAssociatedObject(app, &delegateKey, delegate, .OBJC_ASSOCIATION_RETAIN)
        app.run()
    }
}

nonisolated(unsafe) private var delegateKey = 0
