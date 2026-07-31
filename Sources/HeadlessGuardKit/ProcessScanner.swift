import Foundation

public struct ProcessSnapshotParser: Sendable {
    public init() {}

    public func parse(_ output: String) -> [SystemProcess] {
        output.split(whereSeparator: \.isNewline).compactMap { rawLine in
            parseLine(String(rawLine))
        }
    }

    public func parseLine(_ line: String) -> SystemProcess? {
        let pattern = #"^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\S+)\s+([\d.]+)\s+(\d+)\s+(\S+)\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges == 10 else {
            return nil
        }

        func capture(_ index: Int) -> String? {
            guard let range = Range(match.range(at: index), in: line) else { return nil }
            return String(line[range])
        }

        guard let uidString = capture(1), let userID = UInt32(uidString),
              let pidString = capture(2), let pid = Int32(pidString),
              let parentString = capture(3), let parentPID = Int32(parentString),
              let groupString = capture(4), let processGroupID = Int32(groupString),
              let state = capture(5),
              let cpuString = capture(6), let cpuPercent = Double(cpuString),
              let rssString = capture(7), let rssKB = UInt64(rssString),
              let elapsed = capture(8),
              let commandLine = capture(9) else {
            return nil
        }

        return SystemProcess(
            userID: userID,
            pid: pid,
            parentPID: parentPID,
            processGroupID: processGroupID,
            state: state,
            cpuPercent: cpuPercent,
            residentBytes: rssKB * 1_024,
            elapsedSeconds: Self.parseElapsed(elapsed),
            commandLine: commandLine
        )
    }

    public static func parseElapsed(_ value: String) -> Int {
        var days = 0
        var clock = value
        if let dash = value.firstIndex(of: "-") {
            days = Int(value[..<dash]) ?? 0
            clock = String(value[value.index(after: dash)...])
        }

        let parts = clock.split(separator: ":").compactMap { Int($0) }
        let hours: Int
        let minutes: Int
        let seconds: Int
        switch parts.count {
        case 3:
            hours = parts[0]
            minutes = parts[1]
            seconds = parts[2]
        case 2:
            hours = 0
            minutes = parts[0]
            seconds = parts[1]
        case 1:
            hours = 0
            minutes = 0
            seconds = parts[0]
        default:
            return 0
        }
        return days * 86_400 + hours * 3_600 + minutes * 60 + seconds
    }
}

public struct ProcessScanner: Sendable {
    public init() {}

    public func snapshot() throws -> [SystemProcess] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "uid=,pid=,ppid=,pgid=,state=,%cpu=,rss=,etime=,command="]

        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors

        do {
            try process.run()
        } catch {
            throw HeadlessGuardError.processListingFailed(error.localizedDescription)
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let detail = String(data: errorData, encoding: .utf8) ?? "ps exited with \(process.terminationStatus)"
            throw HeadlessGuardError.processListingFailed(detail)
        }

        guard let text = String(data: data, encoding: .utf8) else {
            throw HeadlessGuardError.processListingFailed("invalid UTF-8 output")
        }
        return ProcessSnapshotParser().parse(text)
    }
}
