import Darwin
import Foundation

public struct ProcessCleaner: Sendable {
    private let scanner: ProcessScanner
    private let detector: ProcessDetector

    public init(scanner: ProcessScanner = ProcessScanner(), detector: ProcessDetector = ProcessDetector()) {
        self.scanner = scanner
        self.detector = detector
    }

    public func clean(
        _ requestedIncident: BrowserIncident,
        gracePeriod: TimeInterval = 1.5
    ) async throws -> CleanupResult {
        guard requestedIncident.isSafeToClean else {
            throw HeadlessGuardError.unsafeIncident("only confirmed automation trees can be terminated")
        }

        let freshProcesses = try scanner.snapshot()
        let freshIncidents = detector.detect(in: freshProcesses)
        guard let incident = freshIncidents.first(where: {
            $0.rootProcess.pid == requestedIncident.rootProcess.pid && $0.isSafeToClean
        }) else {
            throw HeadlessGuardError.staleIncident
        }

        let protectedPIDs = ancestorPIDs(of: getpid(), in: freshProcesses).union([getpid(), getppid()])
        let targets = incident.processes.filter { !protectedPIDs.contains($0.pid) }
        guard !targets.isEmpty else {
            throw HeadlessGuardError.unsafeIncident("the cleanup tree intersects Headless Guard itself")
        }

        let browserTargets = Set(incident.browserProcesses.map(\.pid))
        let targetByPID = Dictionary(uniqueKeysWithValues: targets.map { ($0.pid, $0) })
        let ordered = targets.sorted { left, right in
            if left.pid == incident.rootProcess.pid { return true }
            if right.pid == incident.rootProcess.pid { return false }
            if browserTargets.contains(left.pid) != browserTargets.contains(right.pid) {
                return browserTargets.contains(left.pid)
            }
            return left.pid < right.pid
        }

        var termSent: [Int32] = []
        for process in ordered where process.pid > 1 {
            if Darwin.kill(process.pid, SIGTERM) == 0 || errno == ESRCH {
                termSent.append(process.pid)
            }
        }

        try await Task.sleep(nanoseconds: UInt64(max(0.2, gracePeriod) * 1_000_000_000))

        let afterTerm = try scanner.snapshot()
        let stillMatching = matchingOriginalProcesses(targetByPID, in: afterTerm)
        var forced: [Int32] = []
        for process in stillMatching where process.pid > 1 {
            if Darwin.kill(process.pid, SIGKILL) == 0 || errno == ESRCH {
                forced.append(process.pid)
            }
        }

        if !forced.isEmpty {
            try await Task.sleep(nanoseconds: 350_000_000)
        }
        let final = try scanner.snapshot()
        let survivors = matchingOriginalProcesses(targetByPID, in: final).map(\.pid).sorted()

        return CleanupResult(
            incidentID: incident.id,
            terminatedPIDs: termSent.sorted(),
            forcedPIDs: forced.sorted(),
            survivingPIDs: survivors,
            estimatedFreedBytes: survivors.isEmpty ? incident.residentBytes : 0
        )
    }

    private func ancestorPIDs(of pid: Int32, in processes: [SystemProcess]) -> Set<Int32> {
        let byPID = Dictionary(uniqueKeysWithValues: processes.map { ($0.pid, $0) })
        var result = Set<Int32>()
        var current = pid
        for _ in 0..<32 {
            guard let process = byPID[current], process.parentPID > 0 else { break }
            result.insert(process.parentPID)
            current = process.parentPID
        }
        return result
    }

    private func matchingOriginalProcesses(
        _ originals: [Int32: SystemProcess],
        in current: [SystemProcess]
    ) -> [SystemProcess] {
        current.filter { process in
            guard let original = originals[process.pid] else { return false }
            return fingerprint(original.commandLine) == fingerprint(process.commandLine)
                && abs(original.elapsedSeconds - process.elapsedSeconds) < 120
        }
    }

    private func fingerprint(_ commandLine: String) -> String {
        String(commandLine.prefix(512))
    }
}
