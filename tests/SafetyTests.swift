import Foundation
import Darwin

class FakeEnvironment: SafetyEnvironment {
    var now: TimeInterval = 100
    var boot = "test-boot"
    var flag = false
    var permissions = true
    var healthy = true
    var maintenance = false
    var record: SleepLease?
    var failEnable = false
    var failClear = false
    var failRead = false
    var failWrite = false
    var failClearVerification = false
    var partialEnableFailure = false
    var changes: [Bool] = []
    func readFlag() throws -> Bool {
        if failRead { throw SafetyFailure("read failed") }
        return flag
    }
    func setFlag(_ enabled: Bool) throws {
        changes.append(enabled)
        if enabled && partialEnableFailure { flag = true; throw SafetyFailure("partial enable") }
        if !permissions || (enabled ? failEnable : failClear) { throw SafetyFailure("permission/pmset failure") }
        if !enabled && failClearVerification { return }
        flag = enabled
    }
    func permissionsAvailable() -> Bool { permissions }
    func loadLease() throws -> SleepLease? { record }
    func saveLease(_ lease: SleepLease?) throws {
        if failWrite { throw SafetyFailure("disk failure") }
        record = lease
    }
    func watchdogHealthy() -> Bool { healthy }
    func maintenanceEnabled() -> Bool { maintenance }
    func setMaintenance(_ enabled: Bool) throws { maintenance = enabled }
}

// Real process/filesystem tests use the SAME ownership serializer and kernel lock as
// production, with only flag/clock/permissions replaced. No production CLI test overrides.
final class FileEnvironment: FakeEnvironment {
    let directory: URL
    let crashOnEnable: Bool
    init(_ directory: URL, now: TimeInterval, crashOnEnable: Bool = false) {
        self.directory = directory
        self.crashOnEnable = crashOnEnable
        super.init()
        self.now = now
    }
    override func readFlag() throws -> Bool {
        (try? String(contentsOf: directory.appendingPathComponent("fake-flag"), encoding: .utf8)) == "1"
    }
    override func setFlag(_ enabled: Bool) throws {
        try SafetyPersistence.write(Data((enabled ? "1" : "0").utf8), to: directory.appendingPathComponent("fake-flag"))
        if crashOnEnable && enabled { kill(getpid(), SIGKILL) }
    }
    override func maintenanceEnabled() -> Bool { FileManager.default.fileExists(atPath: directory.appendingPathComponent("maintenance").path) }
    override func setMaintenance(_ enabled: Bool) throws {
        let url = directory.appendingPathComponent("maintenance")
        if enabled { try SafetyPersistence.write(Data("maintenance".utf8), to: url) }
        else if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
    override func loadLease() throws -> SleepLease? { try OwnershipFile(url: directory.appendingPathComponent("ownership.json")).load() }
    override func saveLease(_ lease: SleepLease?) throws { try OwnershipFile(url: directory.appendingPathComponent("ownership.json")).save(lease) }
}

@main enum SafetyTests {
    static var passed = 0
    static var failed = 0
    static func check(_ condition: @autoclosure () throws -> Bool, _ name: String) {
        if (try? condition()) == true { passed += 1; print("PASS \(name)") }
        else { failed += 1; print("FAIL \(name)") }
    }
    static func rejects(_ name: String, _ action: () throws -> Void) {
        do { try action(); check(false, name) } catch { check(true, name) }
    }
    static func fixture(_ args: [String]) throws {
        let directory = URL(fileURLWithPath: args[1])
        let transaction = try SafetyTransaction(directory: directory)
        defer { withExtendedLifetime(transaction) {} }
        let env = FileEnvironment(directory, now: Double(args[3])!, crashOnEnable: args[0] == "crash")
        let engine = SleepSafety(env)
        switch args[0] {
        case "arm", "crash": try engine.arm(owner: args[2])
        case "renew": try engine.renew(owner: args[2])
        case "tick": try engine.watchdog()
        case "off": try engine.stop(owner: args[2])
        case "quiesce": try engine.quiesce()
        case "hold":
            try Data("locked".utf8).write(to: directory.appendingPathComponent("locked"))
            Thread.sleep(forTimeInterval: 10)
        default: throw SafetyFailure("invalid fixture")
        }
    }
    static func child(_ verb: String, _ directory: URL, _ owner: String, _ now: Int = 100) throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        process.arguments = ["fixture", verb, directory.path, owner, String(now)]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        return process
    }
    static func main() throws {
        let args = Array(CommandLine.arguments.dropFirst())
        if args.first == "fixture" {
            do { try fixture(Array(args.dropFirst())); exit(0) } catch { exit(1) }
        }
        check(PasswordlessPolicy.accepts("Sudoers entry:\n    Options: !authenticate\n    Commands:\n        /usr/bin/pmset"), "explicit passwordless policy accepted")
        check(!PasswordlessPolicy.accepts("Sudoers entry:\n    Options: authenticate"), "password-required policy rejected")
        check(!PasswordlessPolicy.accepts("Sudoers entry:\n    Options: !authenticate, authenticate"), "later password requirement wins")
        check(PasswordlessPolicy.accepts("Sudoers entry:\n    Options: !authenticate, !env_reset"), "unrelated policy options preserve passwordless tag")
        check(!PasswordlessPolicy.accepts("/usr/bin/pmset -a disablesleep 0"), "allowed command without passwordless evidence rejected")
        check(!PasswordlessPolicy.accepts("Sudoers entry:\n    Options: !authenticate\nSudoers entry:\n    Commands: ALL"), "later matching entry does not inherit prior passwordless tag")
        let owner = UUID().uuidString, other = UUID().uuidString
        let env = FakeEnvironment(), engine = SleepSafety(env)
        try engine.arm(owner: owner)
        check(env.flag && env.record?.owner == owner, "arm records ownership before enabling")
        check(env.record?.deadline == 145, "short lease is exactly 45 seconds")
        env.now = 110
        try engine.renew(owner: owner)
        check(env.record?.deadline == 155, "renew extends a live lease")
        try engine.terminateSession(owner: owner)
        check(!env.flag && env.record == nil, "normal exit restores and releases ownership")

        var power = PowerRemovalPolicy()
        check(!power.update(externalPower: true, enabled: true), "initial AC snapshot does not stop")
        try engine.arm(owner: owner)
        if power.update(externalPower: false, enabled: true) { try engine.stop(owner: owner) }
        check(!env.flag && env.record == nil, "power removal restores owned sleep")
        check(!power.update(externalPower: true, enabled: true) && !env.flag, "power return never re-arms")
        check(!power.update(externalPower: false, enabled: false), "optional power-removal setting can be disabled")
        check(!power.update(externalPower: nil, enabled: true), "unknown power notification does not invent an edge")
        _ = power.update(externalPower: true, enabled: true)
        check(!power.update(externalPower: nil, enabled: true) && power.update(externalPower: false, enabled: true), "unknown snapshot preserves preceding AC edge")

        env.flag = true
        rejects("refuse pre-existing external sleep prevention") { try engine.arm(owner: owner) }
        try engine.stop(owner: owner)
        try engine.watchdog()
        check(env.flag && env.changes.last == false, "exit and watchdog never clear an unowned flag")
        env.flag = false
        env.permissions = false
        rejects("missing permissions block arming") { try engine.arm(owner: owner) }
        check(!env.flag && env.record == nil, "failed permission preflight has no side effects")
        env.permissions = true
        env.healthy = false
        rejects("missing watchdog blocks arming") { try engine.arm(owner: owner) }
        env.healthy = true
        env.failWrite = true
        rejects("failed ownership write blocks pmset") { try engine.arm(owner: owner) }
        check(!env.flag && env.record == nil, "failed write leaves normal sleep")
        env.failWrite = false
        env.failRead = true
        rejects("failed state read blocks arming") { try engine.arm(owner: owner) }
        env.failRead = false
        env.failEnable = true
        rejects("failed pmset enable reported") { try engine.arm(owner: owner) }
        check(!env.flag && env.record == nil, "failed arm rolls back")
        env.failEnable = false
        env.partialEnableFailure = true
        rejects("partially successful pmset is reported as failed") { try engine.arm(owner: owner) }
        check(!env.flag && env.record == nil, "partial enable failure restores normal sleep")
        env.partialEnableFailure = false

        try engine.arm(owner: owner)
        rejects("concurrent session cannot steal ownership") { try engine.arm(owner: other) }
        try engine.terminateSession(owner: other)
        check(env.flag && env.record?.owner == owner, "another session's clean exit leaves owner unchanged")
        rejects("concurrent session cannot release owner") { try engine.stop(owner: other) }
        rejects("concurrent session cannot renew owner") { try engine.renew(owner: other) }
        env.permissions = false
        rejects("failed clear permission is explicit") { try engine.stop(owner: owner) }
        check(env.flag && env.record?.stopping == true, "failed clear retains ownership and recovery intent")
        rejects("failed watchdog clear is explicit") { try engine.watchdog() }
        check(env.flag && env.record != nil, "failed watchdog leaves journal intact")
        rejects("stopping lease cannot be renewed") { try engine.renew(owner: owner) }
        rejects("failed restore blocks lifecycle teardown") { try engine.quiesce() }
        check(env.maintenance && env.record != nil, "failed lifecycle keeps fence and recovery evidence")
        env.permissions = true
        try engine.watchdog()
        check(!env.flag && env.record == nil, "permission recovery retries and verifies normal sleep")
        env.maintenance = false
        try engine.arm(owner: owner)
        env.failClearVerification = true
        rejects("exit status alone cannot claim restored sleep") { try engine.stop(owner: owner) }
        check(env.record != nil && env.flag, "failed verification keeps recovery")
        env.failClearVerification = false
        try engine.watchdog()
        check(!env.flag && env.record == nil, "verification failure subsequently recovers")

        try engine.arm(owner: owner)
        env.healthy = false
        rejects("watchdog loss stops renewal") { try engine.renew(owner: owner) }
        check(!env.flag && env.record == nil, "watchdog loss restores owned sleep")
        env.healthy = true
        try engine.arm(owner: owner)
        env.flag = false
        rejects("external OFF is never re-enabled by renewal") { try engine.renew(owner: owner) }
        check(!env.flag && env.record == nil, "external OFF relinquishes ownership")

        try engine.arm(owner: owner)
        env.now += 44
        try engine.watchdog()
        check(env.flag, "watchdog preserves live owned lease")
        env.now += 1
        rejects("expired lease cannot revive") { try engine.renew(owner: owner) }
        try engine.watchdog()
        check(!env.flag && env.record == nil, "expiry/crash restores sleep at deadline")
        try engine.arm(owner: owner)
        env.record!.deadline = env.now + 3600
        try engine.watchdog()
        check(!env.flag && env.record == nil, "long/corrupt horizon cannot prolong keep-awake")
        try engine.arm(owner: owner)
        env.boot = "new-boot"
        try engine.watchdog()
        check(env.flag && env.record == nil, "old boot record never authorizes clearing current state")
        env.flag = false // simulated new boot/external state cleanup
        try engine.quiesce()
        rejects("maintenance fence blocks re-arming") { try engine.arm(owner: owner) }
        check(!env.flag && env.record == nil, "successful teardown starts from verified normal sleep")

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("sleepless-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = OwnershipFile(url: root.appendingPathComponent("ownership.json"))
        let valid = SleepLease(version: 1, boot: "test-boot", owner: owner, deadline: 145, stopping: false)
        try file.save(valid)
        check(try file.load() == valid, "production ownership serializer round-trips")
        var duplicate = try String(contentsOf: file.url, encoding: .utf8)
        duplicate.removeLast()
        duplicate += ",\"owner\":\"\(owner)\"}"
        try Data(duplicate.utf8).write(to: file.url)
        rejects("duplicate fields in otherwise valid ownership record rejected") { _ = try file.load() }
        try Data("not JSON".utf8).write(to: file.url)
        rejects("malformed ownership record rejected") { _ = try file.load() }
        try Data(repeating: 65, count: 5000).write(to: file.url)
        rejects("oversized ownership record rejected") { _ = try file.load() }
        try file.save(nil)

        // Actual concurrent processes race under the production kernel lock.
        for index in 0..<12 {
            let a = try child("arm", root, owner), b = try child("arm", root, other)
            a.waitUntilExit(); b.waitUntilExit()
            check((a.terminationStatus == 0) != (b.terminationStatus == 0), "concurrent arms have exactly one winner #\(index)")
            let reader = FileEnvironment(root, now: 100)
            let winner = try file.load()!.owner
            let off = try child("off", root, winner)
            off.waitUntilExit()
            check(try off.terminationStatus == 0 && !(try reader.readFlag()) && (try file.load()) == nil, "concurrent test leaves normal sleep #\(index)")
        }
        let crash = try child("crash", root, owner)
        crash.waitUntilExit()
        check(try crash.terminationReason == .uncaughtSignal && (try file.load())?.owner == owner, "SIGKILL during pmset leaves durable ownership")
        let recovery = try child("tick", root, owner, 146)
        recovery.waitUntilExit()
        check(try recovery.terminationStatus == 0 && !(try FileEnvironment(root, now: 146).readFlag()) && (try file.load()) == nil, "independent process recovers killed owner and acquires released lock")
        for index in 0..<8 {
            let arm = try child("arm", root, owner)
            arm.waitUntilExit()
            let renew = try child("renew", root, owner, 120)
            let tick = try child("tick", root, owner, 120)
            renew.waitUntilExit(); tick.waitUntilExit()
            check(try FileEnvironment(root, now: 120).readFlag(), "concurrent renewal/tick preserves live session #\(index)")
            let expiredRenew = try child("renew", root, owner, 200)
            let expiredTick = try child("tick", root, owner, 200)
            expiredRenew.waitUntilExit(); expiredTick.waitUntilExit()
            let retryTick = try child("tick", root, owner, 200)
            retryTick.waitUntilExit()
            check(try expiredRenew.terminationStatus != 0 && !(try FileEnvironment(root, now: 200).readFlag()) && (try file.load()) == nil,
                  "expiry race cannot revive lease; normal sleep verified #\(index)")
        }
        let beforeUpgrade = try child("arm", root, owner)
        beforeUpgrade.waitUntilExit()
        let quiesce = try child("quiesce", root, owner)
        quiesce.waitUntilExit()
        let lateArm = try child("arm", root, other)
        lateArm.waitUntilExit()
        check(try quiesce.terminationStatus == 0 && lateArm.terminationStatus != 0 && !(try FileEnvironment(root, now: 100).readFlag()),
              "lifecycle fence prevents a different process re-arming during removal")
        try FileEnvironment(root, now: 100).setMaintenance(false)
        let held = try child("hold", root, owner)
        for _ in 0..<100 where !FileManager.default.fileExists(atPath: root.appendingPathComponent("locked").path) { Thread.sleep(forTimeInterval: 0.01) }
        let contender = try child("arm", root, owner)
        contender.waitUntilExit()
        check(contender.terminationStatus != 0, "busy transaction refuses arming")
        kill(held.processIdentifier, SIGKILL); held.waitUntilExit()
        let next = try child("arm", root, owner)
        next.waitUntilExit()
        check(next.terminationStatus == 0, "kernel lock recovers after abrupt process death")
        let cleanExit = try child("off", root, owner)
        cleanExit.waitUntilExit()
        check(try cleanExit.terminationStatus == 0 && !(try FileEnvironment(root, now: 100).readFlag()), "all subprocess tests finish in normal sleep")
        print("\(passed) passed, \(failed) failed")
        if failed != 0 { exit(1) }
    }
}
