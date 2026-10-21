import Foundation
import Darwin

// No test environment overrides in the production executable. Automated tests inject
// SafetyEnvironment directly; they cannot redirect a real pmset command.
final class MacSafetyEnvironment: SafetyEnvironment {
    let directory: URL
    let boot: String
    var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
    private var leaseURL: URL { directory.appendingPathComponent("ownership.json") }
    private var healthURL: URL { directory.appendingPathComponent("watchdog-health.json") }
    private var maintenanceURL: URL { directory.appendingPathComponent("maintenance") }

    init() throws {
        guard getuid() != 0 else { throw SafetyFailure("Run the recovery helper as the logged-in user, never as root.") }
        directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Sleepless/Safety")
        var value = timeval()
        var size = MemoryLayout<timeval>.size
        guard sysctlbyname("kern.boottime", &value, &size, nil, 0) == 0 else { throw SafetyFailure("Cannot identify this boot.") }
        boot = "\(value.tv_sec):\(value.tv_usec)"
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let attributes = try FileManager.default.attributesOfItem(atPath: directory.path)
        guard (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == getuid(),
              attributes[.type] as? FileAttributeType == .typeDirectory else { throw SafetyFailure("Unsafe safety-state directory.") }
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
    }

    static func command(_ path: String, _ arguments: [String], timeout: TimeInterval = 5) throws -> (Int32, String) {
        // Isolate each command in its own process group. Timing out only a parent could
        // leave a child pmset alive to mutate the flag after the safety lock was released.
        let capture = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        guard FileManager.default.createFile(atPath: capture.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
            throw SafetyFailure("Cannot capture command result.")
        }
        defer { try? FileManager.default.removeItem(at: capture) }
        var actions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        guard posix_spawn_file_actions_init(&actions) == 0, posix_spawnattr_init(&attributes) == 0 else {
            throw SafetyFailure("Cannot prepare command execution.")
        }
        defer { posix_spawn_file_actions_destroy(&actions); posix_spawnattr_destroy(&attributes) }
        guard posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0) == 0,
              posix_spawn_file_actions_addopen(&actions, STDOUT_FILENO, capture.path, O_WRONLY | O_TRUNC, 0o600) == 0,
              posix_spawn_file_actions_adddup2(&actions, STDOUT_FILENO, STDERR_FILENO) == 0,
              posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT)) == 0,
              posix_spawnattr_setpgroup(&attributes, 0) == 0 else { throw SafetyFailure("Cannot isolate command execution.") }
        let argv = ([path] + arguments).map { strdup($0) } + [nil]
        let environmentStrings: [String] = ["PATH=/usr/bin:/bin:/usr/sbin:/sbin", "LC_ALL=C",
                                            "HOME=" + FileManager.default.homeDirectoryForCurrentUser.path]
        let env = environmentStrings.map { strdup($0) } + [nil]
        defer { argv.forEach { free($0) }; env.forEach { free($0) } }
        var pid: pid_t = 0
        let launched = argv.withUnsafeBufferPointer { argvBuffer in
            env.withUnsafeBufferPointer { envBuffer in
                posix_spawn(&pid, path, &actions, &attributes,
                            UnsafeMutablePointer(mutating: argvBuffer.baseAddress!),
                            UnsafeMutablePointer(mutating: envBuffer.baseAddress!))
            }
        }
        guard launched == 0 else { throw SafetyFailure("Could not launch \(path): \(String(cString: strerror(launched)))") }
        var status: Int32 = 0
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        while true {
            let waited = waitpid(pid, &status, WNOHANG)
            if waited == pid { break }
            if waited == -1 && errno != EINTR { throw SafetyFailure("Cannot obtain command result.") }
            if ProcessInfo.processInfo.systemUptime >= deadline {
                kill(-pid, SIGKILL)
                while waitpid(pid, &status, 0) == -1 && errno == EINTR {}
                throw SafetyFailure("Command timed out: \(path). Recovery remains active.")
            }
            Thread.sleep(forTimeInterval: 0.02)
        }
        let result: Int32 = status & 0x7f == 0 ? (status >> 8) & 0xff : 128 + (status & 0x7f)
        return (result, (try? String(contentsOf: capture, encoding: .utf8)) ?? "")
    }

    private var agentLabel: String { "com.aboudjem.Sleepless.watchdog" }
    private var agentDomain: String { "gui/\(getuid())" }
    private var installedTool: URL { directory.appendingPathComponent("SleeplessSafety") }
    private var agentPlist: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/" + agentLabel + ".plist")
    }
    private func agentLoaded() -> Bool {
        (try? Self.command("/bin/launchctl", ["print", agentDomain + "/" + agentLabel]).0) == 0
    }
    func installAgent(engine: SleepSafety) throws {
        let source = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        let binary = try Data(contentsOf: source)
        let properties: [String: Any] = ["Label": agentLabel,
            "ProgramArguments": [installedTool.path, "watchdog"],
            "StartInterval": 10, "RunAtLoad": true,
            "ProcessType": "Background", "ExitTimeOut": 10,
            "StandardErrorPath": directory.appendingPathComponent("watchdog.log").path]
        let plist = try PropertyListSerialization.data(fromPropertyList: properties, format: .xml, options: 0)
        let existingPlist = (try? Data(contentsOf: agentPlist)).flatMap {
            try? PropertyListSerialization.propertyList(from: $0, options: [], format: nil) as? NSDictionary
        }
        let same = (try? Data(contentsOf: installedTool)) == binary && existingPlist?.isEqual(to: properties) == true
        if same && agentLoaded() && !maintenanceEnabled() { return }
        // Upgrade restores owned state BEFORE replacing the recovery program. The global
        // transaction lock also fences all GUI arms and watchdog decisions during replacement.
        try engine.quiesce()
        if FileManager.default.fileExists(atPath: healthURL.path) { try FileManager.default.removeItem(at: healthURL) }
        try persist(binary, to: installedTool)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: installedTool.path)
        try FileManager.default.createDirectory(at: agentPlist.deletingLastPathComponent(), withIntermediateDirectories: true)
        try persist(plist, to: agentPlist)
        if agentLoaded() {
            let result = try Self.command("/bin/launchctl", ["bootout", agentDomain + "/" + agentLabel])
            guard result.0 == 0 else { throw SafetyFailure("Could not unload the old watchdog: " + result.1) }
        }
        let result = try Self.command("/bin/launchctl", ["bootstrap", agentDomain, agentPlist.path])
        guard result.0 == 0, agentLoaded() else { throw SafetyFailure("Could not load the watchdog: " + result.1) }
        try setMaintenance(false)
    }
    func removeAgent(engine: SleepSafety) throws {
        try engine.quiesce() // on failure, remove NOTHING; maintenance fence persists
        if agentLoaded() {
            let result = try Self.command("/bin/launchctl", ["bootout", agentDomain + "/" + agentLabel])
            guard result.0 == 0, !agentLoaded() else { throw SafetyFailure("Could not unload watchdog: " + result.1) }
        }
        for file in [agentPlist, installedTool, healthURL] where FileManager.default.fileExists(atPath: file.path) {
            try FileManager.default.removeItem(at: file)
        }
        // Keep the maintenance fence and stable lock inode; a still-running app cannot re-arm.
    }

    func readFlag() throws -> Bool { try Self.readSystemFlag() }
    static func readSystemFlag() throws -> Bool {
        let (status, text) = try Self.command("/usr/bin/pmset", ["-g"])
        guard status == 0 else { throw SafetyFailure("Cannot read macOS sleep state: \(text)") }
        let rows = text.split(separator: "\n").filter { $0.lowercased().contains("sleepdisabled") }
        guard rows.count <= 1 else { throw SafetyFailure("Ambiguous macOS sleep state.") }
        guard let row = rows.first else { return false }
        let field = row.split(whereSeparator: { $0.isWhitespace }).last
        guard field == "0" || field == "1" else { throw SafetyFailure("Unrecognised macOS sleep state.") }
        return field == "1"
    }
    func setFlag(_ enabled: Bool) throws {
        let (status, text) = try Self.command("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "-a", "disablesleep", enabled ? "1" : "0"])
        guard status == 0 else { throw SafetyFailure("pmset failed (\(status)): \(text.trimmingCharacters(in: .whitespacesAndNewlines))") }
    }
    func permissionsAvailable() -> Bool {
        // Listing authorization checks both directions without executing either command.
        for flag in ["0", "1"] {
            guard let result = try? Self.command("/usr/bin/sudo", ["-n", "-ll", "/usr/bin/pmset", "-a", "disablesleep", flag]), result.0 == 0,
                  PasswordlessPolicy.accepts(result.1) else { return false }
        }
        return true
    }
    func loadLease() throws -> SleepLease? { try OwnershipFile(url: leaseURL).load() }
    func saveLease(_ lease: SleepLease?) throws { try OwnershipFile(url: leaseURL).save(lease) }
    private func persist(_ data: Data, to url: URL) throws { try SafetyPersistence.write(data, to: url) }
    struct Health: Codable { let version: Int; let boot: String; let time: TimeInterval }
    func watchdogHealthy() -> Bool {
        guard let data = try? Data(contentsOf: healthURL), let value = try? JSONDecoder().decode(Health.self, from: data),
              value.version == 1, value.boot == boot, value.time <= now, now - value.time < 25 else { return false }
        let loaded = try? Self.command("/bin/launchctl", ["print", "gui/\(getuid())/com.aboudjem.Sleepless.watchdog"])
        return loaded?.0 == 0
    }
    func heartbeat() throws { try persist(JSONEncoder().encode(Health(version: 1, boot: boot, time: now)), to: healthURL) }
    func maintenanceEnabled() -> Bool { FileManager.default.fileExists(atPath: maintenanceURL.path) }
    func setMaintenance(_ enabled: Bool) throws {
        if enabled { try persist(Data("maintenance\n".utf8), to: maintenanceURL) }
        else if maintenanceEnabled() { try FileManager.default.removeItem(at: maintenanceURL) }
    }
}
