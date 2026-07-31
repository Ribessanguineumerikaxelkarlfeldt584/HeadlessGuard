import Darwin
import Foundation
import HeadlessGuardKit

@main
struct HeadlessGuardCLI {
    static let version = "0.1.0"

    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let command = arguments.first ?? "scan"
        let options = Array(arguments.dropFirst())

        do {
            switch command {
            case "scan", "status":
                try scan(json: options.contains("--json"), explain: options.contains("--explain"))
            case "clean", "rescue":
                try await rescue(options: options)
            case "watch":
                try await watch(options: options)
            case "doctor":
                try doctor()
            case "version", "--version", "-v":
                print("Headless Guard \(version)")
            case "help", "--help", "-h":
                printHelp()
            default:
                fputs("Unknown command: \(command)\n\n", stderr)
                printHelp()
                Darwin.exit(64)
            }
        } catch {
            fputs("headless-guard: \(error.localizedDescription)\n", stderr)
            Darwin.exit(1)
        }
    }

    private static func currentIncidents() throws -> [BrowserIncident] {
        let snapshot = try ProcessScanner().snapshot()
        return ProcessDetector().detect(in: snapshot)
    }

    private static func scan(json: Bool, explain: Bool) throws {
        let incidents = try currentIncidents()
        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(incidents)
            print(String(decoding: data, as: UTF8.self))
            return
        }

        if incidents.isEmpty {
            print("✓ No automated headless browser sessions detected.")
            return
        }

        print("Found \(incidents.count) automated browser session\(incidents.count == 1 ? "" : "s"):\n")
        for incident in incidents {
            let safety = incident.isSafeToClean ? "safe to clean" : "review only"
            print("● \(incident.source)  [\(incident.confidence.rawValue), \(incident.score)/100, \(safety)]")
            print("  PID \(incident.rootProcess.pid) · \(incident.processCount) processes · \(GuardFormatting.bytes(incident.residentBytes)) · \(GuardFormatting.duration(incident.elapsedSeconds))")
            if explain {
                for reason in incident.reasons {
                    print("  +\(reason.score) \(reason.title): \(reason.detail)")
                }
            }
            print("")
        }
    }

    private static func rescue(options: [String]) async throws {
        let incidents = try currentIncidents()
        let requestedPID = optionValue("--pid", in: options).flatMap(Int32.init)
        let selected = incidents.filter { incident in
            incident.isSafeToClean && (requestedPID == nil || incident.rootProcess.pid == requestedPID)
        }

        guard !selected.isEmpty else {
            print("✓ Nothing is eligible for safe cleanup.")
            return
        }

        print("Cleanup preview:\n")
        for incident in selected {
            print("  • \(incident.source): PID \(incident.rootProcess.pid) + \(incident.processCount - 1) descendants, \(GuardFormatting.bytes(incident.residentBytes))")
        }
        print("\nProtected: ordinary browser windows, normal profiles, unrelated Node/Codex workers.")

        if options.contains("--dry-run") {
            print("\nDry run only. Re-run with --yes to apply.")
            return
        }

        if !options.contains("--yes") {
            guard isatty(STDIN_FILENO) == 1 else {
                throw HeadlessGuardError.unsafeIncident("non-interactive cleanup requires --yes")
            }
            print("\nStop these confirmed automation sessions? [y/N] ", terminator: "")
            guard let answer = readLine()?.lowercased(), answer == "y" || answer == "yes" else {
                print("Cancelled.")
                return
            }
        }

        let cleaner = ProcessCleaner()
        var hadFailure = false
        var freed: UInt64 = 0
        for incident in selected {
            let result = try await cleaner.clean(incident)
            freed += result.estimatedFreedBytes
            if result.succeeded {
                print("✓ Stopped \(incident.source) (\(result.terminatedPIDs.count) processes, \(GuardFormatting.bytes(result.estimatedFreedBytes)) reclaimed)")
            } else {
                hadFailure = true
                print("! Remaining PIDs for \(incident.source): \(result.survivingPIDs.map(String.init).joined(separator: ", "))")
            }
        }

        try await Task.sleep(nanoseconds: 2_000_000_000)
        let reappeared = try currentIncidents().filter(\.isSafeToClean)
        if reappeared.isEmpty {
            print("✓ Two-second revival check passed. Ordinary Chrome was not targeted.")
        } else {
            hadFailure = true
            print("! \(reappeared.count) confirmed session(s) appeared again. Inspect the launcher before retrying.")
        }
        print("Reclaimed approximately \(GuardFormatting.bytes(freed)).")
        if hadFailure { Darwin.exit(2) }
    }

    private static func watch(options: [String]) async throws {
        let interval = max(2, Int(optionValue("--interval", in: options) ?? "5") ?? 5)
        let autoClean = options.contains("--auto-clean")
        let minimumAgeMinutes = max(15, Int(optionValue("--older-than", in: options) ?? "120") ?? 120)
        var lastSignature = ""
        var cleanedRoots = Set<Int32>()

        print("Headless Guard is watching every \(interval)s (\(autoClean ? "auto-clean confirmed orphans" : "observe only")). Press Ctrl-C to stop.")
        while true {
            let incidents = try currentIncidents()
            let signature = incidents.map { "\($0.rootProcess.pid):\($0.score)" }.joined(separator: ",")
            if signature != lastSignature {
                if incidents.isEmpty {
                    print("[\(ISO8601DateFormatter().string(from: Date()))] clear")
                } else {
                    for incident in incidents {
                        print("[\(ISO8601DateFormatter().string(from: Date()))] \(incident.source) · \(GuardFormatting.bytes(incident.residentBytes)) · \(incident.confidence.rawValue)")
                    }
                }
                lastSignature = signature
            }

            if autoClean {
                let candidates = incidents.filter {
                    $0.isSafeToClean
                        && $0.isOrphaned
                        && $0.elapsedSeconds >= minimumAgeMinutes * 60
                        && !cleanedRoots.contains($0.rootProcess.pid)
                }
                for incident in candidates {
                    cleanedRoots.insert(incident.rootProcess.pid)
                    let result = try await ProcessCleaner().clean(incident)
                    print(result.succeeded
                        ? "✓ Auto-cleaned \(incident.source)"
                        : "! Auto-clean incomplete for \(incident.source)")
                }
            }
            try await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
        }
    }

    private static func doctor() throws {
        let scanner = ProcessScanner()
        let start = Date()
        let processes = try scanner.snapshot()
        let elapsed = Date().timeIntervalSince(start)
        let incidents = ProcessDetector().detect(in: processes)

        print("Headless Guard \(version)")
        print("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        print("Architecture: \(machineArchitecture())")
        print("Privileges: \(geteuid() == 0 ? "root (not recommended)" : "current user; no administrator access")")
        print("Process scan: \(processes.count) processes in \(String(format: "%.0f", elapsed * 1_000)) ms")
        print("Confirmed automation: \(incidents.filter { $0.confidence == .confirmed }.count)")
        print("Network/telemetry: none")
    }

    private static func optionValue(_ name: String, in options: [String]) -> String? {
        guard let index = options.firstIndex(of: name), options.indices.contains(index + 1) else { return nil }
        return options[index + 1]
    }

    private static func machineArchitecture() -> String {
        var info = utsname()
        uname(&info)
        return withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }

    private static func printHelp() {
        print("""
        Headless Guard \(version) — keep automation browsers from hijacking your Mac

        USAGE
          headless-guard scan [--json] [--explain]
          headless-guard rescue [--dry-run] [--yes] [--pid PID]
          headless-guard watch [--interval SEC] [--auto-clean --older-than MIN]
          headless-guard doctor

        SAFETY
          Observe-only by default. Cleanup requires confirmed headless + automation
          fingerprints and never targets an ordinary browser profile.
        """)
    }
}
