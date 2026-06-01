// App.swift. Sleepless: a standalone menu-bar toggle that keeps the Mac running
// with the lid closed (on battery, no external display) via `pmset disablesleep`.
//
// Mechanism (verified live on this machine; disablesleep is UNDOCUMENTED in
// pmset(1) but real. It sets IORegistry "SleepDisabled" = Yes and disables
// idle + Apple-menu + lid-close clamshell sleep):
//   ON : sudo pmset -a disablesleep 1
//   OFF: sudo pmset -a disablesleep 0
//   READ (no root): pmset -g | grep -i SleepDisabled  (value 1 = ON; 0/absent = OFF)
// The OFF/ON commands run passwordless via a tightly-scoped /etc/sudoers.d drop-in.
// disablesleep is runtime-only and resets to 0 on reboot, and that reset is a
// deliberate safety feature; the app does NOT auto re-arm.
//
// UI: clicking the menu-bar moon opens a small native popover with an NSSwitch
// toggle (the System-Settings control) + a state caption + Quit, aligned to
// macOS design. The menu-bar glyph also shows state at a glance.
//
// Build (mirrors Nexus.app): Command Line Tools `swiftc`, NO Xcode project.
//   swiftc -O -parse-as-library -target arm64-apple-macos26.0 -framework AppKit
//   File MUST be named App.swift and compiled -parse-as-library so the
//   @main enum + @MainActor static main() entry is Swift-6 isolation-safe.
import AppKit

// MARK: - Tunables
private let pollInterval: TimeInterval = 60
// Battery-floor config (user-adjustable via the popover slider; persisted in UserDefaults).
private let floorKey = "batteryFloorPercent"
private let floorDefault = 15
private let floorMin = 5
private let floorMax = 50

// MARK: - Menu-bar moon glyph (native SF Symbols — Apple-drawn, optically tuned)
// We use the system `moon` symbol family rendered as monochrome template images
// so the menu-bar glyph is pixel-perfect and indistinguishable from the OS's own
// status items at every size (no hand-rolled paths, which read "cheap"):
//   OFF   (sleeps normally)        = moon         (HOLLOW crescent = inactive)
//   ON    (kept awake)             = moon.fill    (SOLID crescent  = active)
//   ARMED (on battery, auto-off)   = moon.stars.fill (solid + stars caution)
// All three are one crescent-moon family, so the brand stays consistent and the
// state is conveyed by shape alone (never colour). Hollow-vs-filled is the macOS
// inactive/active convention and reads clearly even at 16 px. isTemplate lets the
// system tint + invert them on the open-menu highlight.
enum SleepGlyph: String {
    case off   = "moon"
    case on    = "moon.fill"
    case armed = "moon.stars.fill"
}

private func makeMoonGlyph(_ glyph: SleepGlyph) -> NSImage {
    let cfg = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        .applying(.init(scale: .medium))
    let img = NSImage(systemSymbolName: glyph.rawValue, accessibilityDescription: "Sleepless")?
        .withSymbolConfiguration(cfg)
        ?? NSImage(systemSymbolName: "moon.fill", accessibilityDescription: "Sleepless")
        ?? NSImage()
    img.isTemplate = true
    return img
}

// Flipped container so popover content lays out top-down with simple frames.
private final class FlippedView: NSView { override var isFlipped: Bool { true } }

// Frosted-glass popover backing: a flipped NSVisualEffectView so content still
// lays out top-down while the panel gets a translucent, blurred "glassmorphism"
// material that samples the desktop/windows behind it (system light/dark aware).
private final class GlassView: NSVisualEffectView { override var isFlipped: Bool { true } }

// Decorative overlay that is genuinely non-interactive: hitTest returns nil so
// mouse events fall through to the controls beneath it (enforced by design, not
// by z-order accident). Used for the violet tint wash over the glass.
private final class PassthroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private let onGlyph = makeMoonGlyph(.on)
    private let offGlyph = makeMoonGlyph(.off)
    private let armedGlyph = makeMoonGlyph(.armed)

    // Popover UI
    private let popover = NSPopover()
    private var toggleSwitch: NSSwitch!
    private var captionLabel: NSTextField!
    private var floorValueLabel: NSTextField!
    private var floorSlider: NSSlider!
    private var clickMonitor: Any?
    private var batteryFloorPercent = floorDefault
    private var isOn = false
    private let popoverWidth: CGFloat = 280
    private let popoverHeight: CGFloat = 240

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        batteryFloorPercent = min(max((UserDefaults.standard.object(forKey: floorKey) as? Int) ?? floorDefault, floorMin), floorMax)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = offGlyph
            button.action = #selector(statusClicked)
            button.target = self
        }
        popover.behavior = .applicationDefined   // app-managed dismissal (no transient close/reopen flicker)
        popover.animates = true
        popover.contentSize = NSSize(width: popoverWidth, height: popoverHeight)
        popover.contentViewController = makeContentController()

        refresh()   // reflect TRUE system state on launch (never a stale assumption)
        timer = Timer.scheduledTimer(timeInterval: pollInterval, target: self,
                                     selector: #selector(poll), userInfo: nil, repeats: true)
    }

    // MARK: - Popover content (native NSSwitch toggle, macOS-aligned)
    private func makeContentController() -> NSViewController {
        let W = popoverWidth, pad: CGFloat = 18
        let contentW = W - pad * 2

        // Frosted-glass base: blurred translucent material that samples what's
        // behind the popover. `.popover` material + `.behindWindow` blending is
        // the macOS-native "glassmorphism" recipe; it stays legible in light and
        // dark and follows the system vibrancy so labels read crisply on top.
        let root = GlassView(frame: NSRect(x: 0, y: 0, width: W, height: popoverHeight))
        root.material = .popover
        root.blendingMode = .behindWindow
        root.state = .active
        root.isEmphasized = true
        // Round our own corners with continuous (squircle) curvature so the
        // rectangular glass never bleeds past the popover's rounded backdrop;
        // masksToBounds also clips the tint child to the same rounded shape.
        root.wantsLayer = true
        root.layer?.cornerRadius = 11
        root.layer?.cornerCurve = .continuous
        root.layer?.masksToBounds = true

        // Faint violet brand wash over the frost (matches the app icon's hue)
        // for a tinted-glass feel. Very low alpha so the blur stays dominant.
        // PassthroughView.hitTest returns nil, so it can never intercept clicks
        // meant for the switch/slider beneath it (enforced, not incidental).
        let tint = PassthroughView(frame: root.bounds)
        tint.autoresizingMask = [.width, .height]
        tint.wantsLayer = true
        tint.layer?.backgroundColor = NSColor(srgbRed: 0.58, green: 0.45, blue: 1.0, alpha: 0.07).cgColor
        root.addSubview(tint)

        // Header: small moon mark + "Sleepless"
        let mark = NSImageView(frame: NSRect(x: pad, y: 16, width: 18, height: 18))
        let headerMoon = makeMoonGlyph(.on); headerMoon.isTemplate = true
        mark.image = headerMoon
        mark.contentTintColor = .labelColor
        root.addSubview(mark)
        let title = makeLabel("Sleepless", font: .systemFont(ofSize: 14, weight: .semibold), color: .labelColor)
        title.frame = NSRect(x: pad + 24, y: 16, width: contentW - 24, height: 20)
        root.addSubview(title)

        // Toggle row: descriptive label (left) + NSSwitch (right)
        let rowLabel = makeLabel("Keep awake with lid closed", font: .systemFont(ofSize: 13), color: .labelColor)
        rowLabel.frame = NSRect(x: pad, y: 52, width: 168, height: 22)
        root.addSubview(rowLabel)

        toggleSwitch = NSSwitch()
        toggleSwitch.target = self
        toggleSwitch.action = #selector(switchToggled(_:))
        let sw = toggleSwitch.intrinsicContentSize
        let swW = sw.width > 0 ? sw.width : 38
        let swH = sw.height > 0 ? sw.height : 21
        toggleSwitch.frame = NSRect(x: W - pad - swW, y: 52 + (22 - swH) / 2, width: swW, height: swH)
        root.addSubview(toggleSwitch)

        // State caption (wraps up to 2 lines)
        captionLabel = makeLabel("", font: .systemFont(ofSize: 11), color: .secondaryLabelColor)
        captionLabel.frame = NSRect(x: pad, y: 82, width: contentW, height: 32)
        captionLabel.usesSingleLineMode = false
        captionLabel.lineBreakMode = .byWordWrapping
        captionLabel.maximumNumberOfLines = 2
        captionLabel.cell?.wraps = true
        root.addSubview(captionLabel)

        let sep1 = NSBox(frame: NSRect(x: pad, y: 122, width: contentW, height: 1))
        sep1.boxType = .separator
        root.addSubview(sep1)

        // Battery-floor setting: label + live value + draggable slider
        let floorLabel = makeLabel("Auto-off at low battery", font: .systemFont(ofSize: 13), color: .labelColor)
        floorLabel.frame = NSRect(x: pad, y: 136, width: contentW - 54, height: 18)
        root.addSubview(floorLabel)

        floorValueLabel = makeLabel("\(batteryFloorPercent)%", font: .systemFont(ofSize: 13, weight: .semibold), color: .secondaryLabelColor)
        floorValueLabel.alignment = .right
        floorValueLabel.frame = NSRect(x: W - pad - 54, y: 136, width: 54, height: 18)
        root.addSubview(floorValueLabel)

        floorSlider = NSSlider(value: Double(batteryFloorPercent), minValue: Double(floorMin), maxValue: Double(floorMax),
                               target: self, action: #selector(floorSliderChanged(_:)))
        floorSlider.isContinuous = true          // live update while dragging
        floorSlider.controlSize = .small
        floorSlider.frame = NSRect(x: pad, y: 160, width: contentW, height: 20)
        root.addSubview(floorSlider)

        let minHint = makeLabel("\(floorMin)%", font: .systemFont(ofSize: 9), color: .tertiaryLabelColor)
        minHint.frame = NSRect(x: pad, y: 181, width: 30, height: 12)
        root.addSubview(minHint)
        let maxHint = makeLabel("\(floorMax)%", font: .systemFont(ofSize: 9), color: .tertiaryLabelColor)
        maxHint.alignment = .right
        maxHint.frame = NSRect(x: W - pad - 30, y: 181, width: 30, height: 12)
        root.addSubview(maxHint)

        let sep2 = NSBox(frame: NSRect(x: pad, y: 200, width: contentW, height: 1))
        sep2.boxType = .separator
        root.addSubview(sep2)

        let quit = NSButton(title: "Quit Sleepless", target: self, action: #selector(quit))
        quit.controlSize = .small
        quit.sizeToFit()
        let qs = quit.frame.size
        quit.frame = NSRect(x: W - pad - qs.width, y: 210, width: qs.width, height: qs.height)
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

    // MARK: - Click the menu-bar moon to open/close the popover
    @objc private func statusClicked() {
        if popover.isShown { closePopover() } else { openPopover() }
    }

    private func openPopover() {
        refresh()                              // sync switch/caption to TRUE state before showing
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // Make the popover key so the switch responds on the FIRST click.
        popover.contentViewController?.view.window?.makeKey()
        // Close when the user clicks anywhere outside the app (status bar, another app, desktop).
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        if let monitor = clickMonitor { NSEvent.removeMonitor(monitor); clickMonitor = nil }
    }

    @objc private func switchToggled(_ sender: NSSwitch) {
        setDisableSleep(sender.state == .on)
        refresh()                              // re-read TRUE state; switch reflects reality, not the click
    }

    @objc private func poll() { refresh() }

    // MARK: - Core state sync
    @objc private func refresh() {
        let on = readSleepDisabled()
        applyUI(on: on)
        if on { enforceBatteryFloor() }
    }

    private func applyUI(on: Bool) {
        isOn = on
        // ARMED = kept awake while actively discharging on battery, so the
        // auto-off safety net is live. Distinct menu-bar glyph (moon + stars).
        var armed = false
        if on {
            let (onBattery, discharging, _) = batteryStatus()
            armed = onBattery && discharging
        }
        if let button = statusItem.button {
            button.image = on ? (armed ? armedGlyph : onGlyph) : offGlyph
            button.toolTip = on
                ? (armed
                    ? "Sleepless: on (battery). Auto-off at \(batteryFloorPercent)%."
                    : "Sleepless: on. Stays awake with the lid closed.")
                : "Sleepless: off. Sleeps normally."
        }
        toggleSwitch?.state = on ? .on : .off
        renderText()
    }

    // Update text labels only (no pmset subprocess; safe to call on every slider tick).
    private func renderText() {
        floorValueLabel?.stringValue = "\(batteryFloorPercent)%"
        captionLabel?.stringValue = isOn
            ? "Stays awake when the lid is closed. Turns off at \(batteryFloorPercent)% battery."
            : "Sleeps normally when you close the lid."
    }

    @objc private func floorSliderChanged(_ sender: NSSlider) {
        let v = min(max(Int(sender.doubleValue.rounded()), floorMin), floorMax)
        if v != batteryFloorPercent {
            batteryFloorPercent = v
            UserDefaults.standard.set(v, forKey: floorKey)
        }
        renderText()
    }

    private func setDisableSleep(_ on: Bool) {
        // sudo -n: never prompt (GUI app has no TTY). The exact argument vector
        // matches the NOPASSWD sudoers grant, so this runs without a password.
        _ = runCapture("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "-a", "disablesleep", on ? "1" : "0"])
    }

    // MARK: - Battery-floor safety net (silent; no extra UI)
    private func enforceBatteryFloor() {
        let (onBattery, discharging, percent) = batteryStatus()
        guard onBattery, discharging, percent <= batteryFloorPercent else { return }
        setDisableSleep(false)
        applyUI(on: readSleepDisabled())
        notify("Battery low (\(percent)%). Sleepless turned off.")
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
        return false   // line absent -> OFF
    }

    private func batteryStatus() -> (onBattery: Bool, discharging: Bool, percent: Int) {
        let out = runCapture("/usr/bin/pmset", ["-g", "batt"])
        let onBattery = out.contains("Battery Power")
        let discharging = out.range(of: "discharging", options: .caseInsensitive) != nil
        var percent = 100
        for tok in out.split(whereSeparator: { " \t\n;".contains($0) }) {
            if tok.hasSuffix("%"), let v = Int(tok.dropLast()) { percent = v; break }
        }
        return (onBattery, discharging, percent)
    }

    // MARK: - Notification (mirrors Nexus' osascript approach)
    private func notify(_ message: String) {
        let script = "display notification \"\(message)\" with title \"Sleepless\" sound name \"Tink\""
        _ = runCapture("/usr/bin/osascript", ["-e", script])
    }

    // MARK: - Process runner (explicit PATH/HOME; captures stdout)
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
