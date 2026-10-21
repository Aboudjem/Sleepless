// Read-only native checks. No SafetyEnvironment instance, agent, sudo or sleep write.
import Foundation
import IOKit.ps

@main enum NativeChecks {
    static func main() throws {
        let before = try MacSafetyEnvironment.readSystemFlag()
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue() else {
            throw SafetyFailure("Native power-source snapshot is unavailable.")
        }
        let power = type as String
        guard power == kIOPSACPowerValue || power == kIOPSBatteryPowerValue || power == kIOPSUPSType else {
            throw SafetyFailure("Unknown native power source: \(power)")
        }
        guard let source = IOPSNotificationCreateRunLoopSource({ _ in }, nil)?.takeRetainedValue() else {
            throw SafetyFailure("Native power notification source could not be created.")
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        let after = try MacSafetyEnvironment.readSystemFlag()
        guard before == after else { throw SafetyFailure("Sleep state changed externally during read-only tests.") }
        print("PASS native IOKit snapshot (\(power)) and notification-source registration")
        print("PASS real sleep state unchanged by read-only tests (SleepDisabled=\(after ? 1 : 0))")
        let falseResult = try MacSafetyEnvironment.command("/usr/bin/false", [])
        guard falseResult.0 != 0 else { throw SafetyFailure("Command runner lost exit status.") }
        do {
            _ = try MacSafetyEnvironment.command("/bin/sleep", ["2"], timeout: 0.05)
            throw SafetyFailure("Command runner failed to enforce its timeout.")
        } catch let error as SafetyFailure {
            guard error.description.contains("timed out") else { throw error }
        }
        let marker = FileManager.default.temporaryDirectory.appendingPathComponent("sleepless-timeout-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: marker) }
        do {
            _ = try MacSafetyEnvironment.command("/bin/sh", ["-c", "/bin/sleep 0.3; /usr/bin/touch '" + marker.path + "'"], timeout: 0.05)
            throw SafetyFailure("Child command was not timed out.")
        } catch let error as SafetyFailure {
            guard error.description.contains("timed out") else { throw error }
        }
        Thread.sleep(forTimeInterval: 0.4)
        guard !FileManager.default.fileExists(atPath: marker.path) else { throw SafetyFailure("Timed-out command left a live child.") }
        print("PASS production process runner reports failures and terminates timed-out command groups")
    }
}
