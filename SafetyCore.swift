// Ownership and short leases, adapted from mmavko/Sleepless's lease/watchdog design.
// The engine is shared by the GUI command helper and watchdog; tests inject the OS boundary.
import Foundation
import Darwin

struct SafetyFailure: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { description = message }
}

struct SleepLease: Codable, Equatable {
    let version: Int
    let boot: String
    let owner: String
    var deadline: TimeInterval
    var stopping: Bool
}

protocol SafetyEnvironment: AnyObject {
    var now: TimeInterval { get }
    var boot: String { get }
    func readFlag() throws -> Bool
    func setFlag(_ enabled: Bool) throws
    func permissionsAvailable() -> Bool
    func loadLease() throws -> SleepLease?
    func saveLease(_ lease: SleepLease?) throws
    func watchdogHealthy() -> Bool
    func maintenanceEnabled() -> Bool
    func setMaintenance(_ enabled: Bool) throws
}

final class SleepSafety {
    static let ttl: TimeInterval = 45
    let environment: SafetyEnvironment
    init(_ environment: SafetyEnvironment) { self.environment = environment }

    private func lease() throws -> SleepLease? {
        guard let value = try environment.loadLease() else { return nil }
        guard value.version == 1, UUID(uuidString: value.owner) != nil,
              value.deadline.isFinite, value.deadline >= 0,
              !value.boot.isEmpty else { throw SafetyFailure("Invalid ownership record; recovery requires attention.") }
        // A reboot resets disablesleep. Never apply an old record to this boot's state.
        if value.boot != environment.boot {
            try environment.saveLease(nil)
            return nil
        }
        return value
    }

    func status(owner: String) throws -> String {
        let record = try lease()
        let on = try environment.readFlag()
        if !on {
            if record != nil { try environment.saveLease(nil) }
            return "off"
        }
        guard let record else { return "external" }
        return record.owner == owner ? "owned" : "other-session"
    }

    func ready() throws {
        guard !environment.maintenanceEnabled() else { throw SafetyFailure("Installation or removal is in progress.") }
        guard environment.watchdogHealthy() else { throw SafetyFailure("Watchdog is unavailable. Keep-awake is blocked.") }
        guard environment.permissionsAvailable() else { throw SafetyFailure("Sleep permissions are unavailable. Complete the one-time setup.") }
    }

    func arm(owner: String) throws {
        guard UUID(uuidString: owner) != nil else { throw SafetyFailure("Invalid session identity.") }
        try ready()
        guard try lease() == nil, try !environment.readFlag() else {
            throw SafetyFailure("Sleep prevention is already enabled or awaiting recovery. Sleepless will not take ownership.")
        }
        // Persist BEFORE touching the global flag. A crash at any subsequent instruction
        // leaves recovery evidence. All calls, including watchdog ticks, hold the same lock.
        try environment.saveLease(SleepLease(version: 1, boot: environment.boot, owner: owner,
                                            deadline: environment.now + Self.ttl, stopping: false))
        do {
            try environment.setFlag(true)
            guard try environment.readFlag() else { throw SafetyFailure("pmset did not enable keep-awake.") }
        } catch {
            // pmset may have changed state despite returning an error. Keep the journal
            // until a verified rollback succeeds; never claim success on a failed call.
            do { try stop(owner: owner) } catch { /* watchdog retains the recovery record */ }
            throw error
        }
    }

    func renew(owner: String) throws {
        guard let record = try lease(), record.owner == owner, !record.stopping,
              record.deadline > environment.now,
              record.deadline <= environment.now + Self.ttl else {
            throw SafetyFailure("Keep-awake lease has ended; it cannot be revived.")
        }
        do { try ready() } catch {
            try? stop(owner: owner)
            throw error
        }
        guard try environment.readFlag() else {
            try environment.saveLease(nil)
            throw SafetyFailure("Normal sleep was restored externally. Keep-awake was not re-enabled.")
        }
        var renewed = record
        renewed.deadline = environment.now + Self.ttl
        try environment.saveLease(renewed)
    }

    func stop(owner: String) throws {
        guard var record = try lease() else { return } // no ownership => no mutation
        guard record.owner == owner else { throw SafetyFailure("Another Sleepless session owns this state.") }
        record.stopping = true
        record.deadline = environment.now
        try environment.saveLease(record)
        if try environment.readFlag() { try environment.setFlag(false) }
        guard try !environment.readFlag() else { throw SafetyFailure("Normal sleep could not be verified. Recovery remains active.") }
        try environment.saveLease(nil)
    }

    func terminateSession(owner: String) throws {
        guard let record = try lease(), record.owner == owner else { return }
        try stop(owner: owner)
    }

    func watchdog() throws {
        guard let record = try lease() else { return } // never clear an unowned flag
        if record.stopping || record.deadline <= environment.now || record.deadline > environment.now + Self.ttl {
            try stop(owner: record.owner)
        } else if try !environment.readFlag() {
            try environment.saveLease(nil)
        }
    }

    // Fence new arms/renewals before upgrade or removal; retain fence and watchdog on failure.
    func quiesce() throws {
        try environment.setMaintenance(true)
        if let record = try lease() { try stop(owner: record.owner) }
        guard try !environment.readFlag() else {
            throw SafetyFailure("Sleep is disabled without Sleepless ownership. Restore it using its owner before continuing.")
        }
    }
}

// Shared, testable edge detector. Returning to AC never arms or renews anything.
struct PowerRemovalPolicy {
    private(set) var externalPower: Bool?
    mutating func update(externalPower next: Bool?, enabled: Bool) -> Bool {
        guard let next else { return false }
        let removed = externalPower == true && !next
        externalPower = next
        return enabled && removed
    }
}

// Kernel-released transaction lock: shared by CLI requests, agent ticks and lifecycle.
// The inode is deliberately retained across uninstall/reinstall to avoid split locks.
final class SafetyTransaction {
    private let fd: Int32
    init(directory: URL) throws {
        fd = open(directory.appendingPathComponent("transaction.lock").path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw SafetyFailure("Cannot open safety lock.") }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            close(fd)
            throw SafetyFailure("Another safety transaction is in progress. Retry shortly.")
        }
    }
    deinit { _ = flock(fd, LOCK_UN); close(fd) }
}

struct OwnershipFile {
    let url: URL
    func load() throws -> SleepLease? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              (attributes[.size] as? NSNumber)?.intValue ?? 4096 < 4096 else {
            throw SafetyFailure("Invalid ownership file.")
        }
        let data = try Data(contentsOf: url)
        let lease = try JSONDecoder().decode(SleepLease.self, from: data)
        // Canonical encoding rejects duplicate/unknown fields and ambiguous hand-edited data.
        guard try encode(lease) == data else { throw SafetyFailure("Noncanonical ownership record.") }
        return lease
    }
    private func encode(_ lease: SleepLease) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(lease)
    }
    func save(_ lease: SleepLease?) throws {
        if let lease { try SafetyPersistence.write(encode(lease), to: url) }
        else if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}

struct SafetyPersistence {
    static func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW)
        guard fd >= 0 else { throw SafetyFailure("Cannot synchronize safety state.") }
        defer { close(fd) }
        guard fsync(fd) == 0 else { throw SafetyFailure("Cannot persist safety state.") }
    }
}

// sudo -ll prints the matching policy in verbose blocks. Require an explicit
// passwordless tag; a cached authorization or merely allowed command is insufficient.
struct PasswordlessPolicy {
    static func accepts(_ listing: String) -> Bool {
        guard let entry = listing.components(separatedBy: "Sudoers entry:").last,
              let options = entry.split(separator: "\n").last(where: {
                  $0.trimmingCharacters(in: .whitespaces).hasPrefix("Options:")
              }) else { return false }
        let values = options.components(separatedBy: "Options:").last!.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return values.last(where: { $0 == "authenticate" || $0 == "!authenticate" }) == "!authenticate"
    }
}
