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
// Fail-safe protections layer on top, with no background daemon:
//   1. Auto-off timer (Off / 15m / 30m / 1h / 2h / 4h / 8h) — one-shot in-memory Timer.
//   2. Battery-floor cutoff (5%–50%, default 15%) — always wins on battery.
//   3. Low-Power-Mode auto-off — on battery, steps aside unless forced on this session.
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

private let lastStopKey = "lastStopReason"

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

// MARK: - AppDelegate
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?

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

    private var loginSwitch: NSSwitch!
    private var clickMonitor: Any?

    // State
    private var masterOn = true              // default ON: prevents idle sleep in normal state
    private var lidClosedOn = false          // opt-in: pmset disablesleep (true system state)
    private var sleepAssertionID: IOPMAssertionID = 0
    private var hasSleepAssertion = false

    private var batteryFloorPercent = floorDefault
    private var userForcedOn = false         // honors deliberate turn-on over LPM auto-off (battery still wins)

    // Auto-off timer (in-memory; dies on quit, never survives a reboot)
    private var autoOffMinutes = 0
    private var keepAwakeTimer: Timer?
    private var countdownTicker: Timer?
    private var timerEndDate: Date?

    private let popoverWidth: CGFloat = 336
    private let popoverHeight: CGFloat = 362

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        batteryFloorPercent = min(max((UserDefaults.standard.object(forKey: floorKey) as? Int) ?? floorDefault, floorMin), floorMax)

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

        // Default ON: prevent idle sleep immediately on launch (unless a safety net blocks it).
        if safetyBlockReason() == nil {
            setIdleAssertion(true)
        } else {
            setIdleAssertion(false)
        }

        refresh()   // sync lid-closed state + enforce safety nets on launch
        timer = Timer.scheduledTimer(timeInterval: pollInterval, target: self,
                                     selector: #selector(poll), userInfo: nil, repeats: true)
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

        // FOOTER — Clean borderless utility bar (Launch at login on left, quiet Quit on right)
        let fy = g3y + g3h + 10, fh: CGFloat = 32
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
            // Fail-closed pre-start guard: refuse to turn on if the battery limit is already tripped.
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
            if lidClosedOn { _ = setDisableSleep(false) }
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
            setIdleAssertion(true)
            userForcedOn = true
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
        if readSleepDisabled() { _ = setDisableSleep(false) }
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
            let pctText = percent.map { "\($0)%" } ?? "?%"
            if lidOn {
                button.toolTip = armed
                    ? "Sleepless: lid-closed on battery (\(pctText)). Auto-off at \(batteryFloorPercent)%."
                    : "Sleepless: awake with lid closed."
            } else if masterOn {
                button.toolTip = "Sleepless: preventing idle sleep."
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
        updateTimerLabels()
    }

    private func renderText() {
        floorValueLabel?.stringValue = "\(batteryFloorPercent)%"
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

    // MARK: - Battery + Low-Power-Mode Safety Nets
    private func safetyBlockReason() -> String? {
        // 1. Hard battery floor (fail-closed if battery percent is unreadable while discharging).
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
        // 2. Low Power Mode auto-off, unless user deliberately forced awake this session.
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
