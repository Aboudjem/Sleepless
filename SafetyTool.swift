import Foundation
import Darwin

@main enum SafetyTool {
    static func main() {
        do {
            let environment = try MacSafetyEnvironment()
            let transaction = try SafetyTransaction(directory: environment.directory)
            defer { withExtendedLifetime(transaction) {} }
            let engine = SleepSafety(environment)
            let args = Array(CommandLine.arguments.dropFirst())
            let owner = args.count == 2 ? args[1] : ""
            switch args.first {
            case "arm": try engine.arm(owner: owner)
            case "renew": try engine.renew(owner: owner)
            case "off": try engine.stop(owner: owner)
            case "exit": try engine.terminateSession(owner: owner)
            case "status": print(try engine.status(owner: owner)); return
            case "ready": try engine.ready()
            case "permissions":
                guard environment.permissionsAvailable() else { throw SafetyFailure("Passwordless authorization is missing for one or both sleep commands.") }
            case "watchdog":
                try engine.watchdog()
                // A failed clear must not advertise a healthy watchdog.
                guard environment.permissionsAvailable() else { throw SafetyFailure("Watchdog sleep permissions are missing.") }
                try environment.heartbeat()
            case "install-agent": try environment.installAgent(engine: engine)
            case "remove-agent": try environment.removeAgent(engine: engine)
            case "quiesce": try engine.quiesce()
            default: throw SafetyFailure("Unknown safety command.")
            }
            print("ok")
        } catch {
            FileHandle.standardError.write(Data("Sleepless safety: \(error)\n".utf8))
            exit(1)
        }
    }
}
