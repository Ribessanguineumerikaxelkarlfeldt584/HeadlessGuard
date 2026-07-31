import Foundation

public enum BrowserFamily: String, Codable, CaseIterable, Sendable {
    case chrome = "Google Chrome"
    case chromium = "Chromium"
    case edge = "Microsoft Edge"
    case firefox = "Firefox"
    case webkit = "WebKit"
    case unknown = "Browser"
}

public enum DetectionConfidence: String, Codable, Sendable {
    case confirmed
    case likely
    case suspicious

    public var scoreFloor: Int {
        switch self {
        case .confirmed: return 80
        case .likely: return 60
        case .suspicious: return 0
        }
    }
}

public struct SystemProcess: Identifiable, Codable, Hashable, Sendable {
    public let userID: UInt32
    public let pid: Int32
    public let parentPID: Int32
    public let processGroupID: Int32
    public let state: String
    public let cpuPercent: Double
    public let residentBytes: UInt64
    public let elapsedSeconds: Int
    public let commandLine: String

    public var id: Int32 { pid }

    public init(
        userID: UInt32,
        pid: Int32,
        parentPID: Int32,
        processGroupID: Int32,
        state: String,
        cpuPercent: Double,
        residentBytes: UInt64,
        elapsedSeconds: Int,
        commandLine: String
    ) {
        self.userID = userID
        self.pid = pid
        self.parentPID = parentPID
        self.processGroupID = processGroupID
        self.state = state
        self.cpuPercent = cpuPercent
        self.residentBytes = residentBytes
        self.elapsedSeconds = elapsedSeconds
        self.commandLine = commandLine
    }

    public var shortCommand: String {
        let lower = commandLine.lowercased()
        if lower.contains("clidaemon.js") { return "Playwright daemon" }
        if lower.contains("chrome-headless-shell") { return "Chrome Headless Shell" }
        if lower.contains("google chrome helper") { return "Chrome helper" }
        if lower.contains("google chrome") { return "Google Chrome" }
        if lower.contains("chromium") { return "Chromium" }
        if lower.contains("puppeteer") { return "Puppeteer runner" }
        if lower.contains("playwright") { return "Playwright runner" }
        return commandLine.split(separator: "/").last.map(String.init) ?? commandLine
    }
}

public struct DetectionReason: Codable, Hashable, Sendable {
    public let title: String
    public let detail: String
    public let score: Int

    public init(title: String, detail: String, score: Int) {
        self.title = title
        self.detail = detail
        self.score = score
    }
}

public struct BrowserIncident: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let source: String
    public let family: BrowserFamily
    public let rootProcess: SystemProcess
    public let browserProcesses: [SystemProcess]
    public let processes: [SystemProcess]
    public let reasons: [DetectionReason]
    public let score: Int
    public let confidence: DetectionConfidence
    public let isOrphaned: Bool
    public let isSafeToClean: Bool

    public init(
        id: String,
        source: String,
        family: BrowserFamily,
        rootProcess: SystemProcess,
        browserProcesses: [SystemProcess],
        processes: [SystemProcess],
        reasons: [DetectionReason],
        score: Int,
        confidence: DetectionConfidence,
        isOrphaned: Bool,
        isSafeToClean: Bool
    ) {
        self.id = id
        self.source = source
        self.family = family
        self.rootProcess = rootProcess
        self.browserProcesses = browserProcesses
        self.processes = processes
        self.reasons = reasons
        self.score = score
        self.confidence = confidence
        self.isOrphaned = isOrphaned
        self.isSafeToClean = isSafeToClean
    }

    public var residentBytes: UInt64 {
        processes.reduce(0) { $0 + $1.residentBytes }
    }

    public var cpuPercent: Double {
        processes.reduce(0) { $0 + $1.cpuPercent }
    }

    public var elapsedSeconds: Int {
        max(rootProcess.elapsedSeconds, browserProcesses.map(\.elapsedSeconds).max() ?? 0)
    }

    public var processCount: Int { processes.count }
}

public struct CleanupResult: Codable, Sendable {
    public let incidentID: String
    public let terminatedPIDs: [Int32]
    public let forcedPIDs: [Int32]
    public let survivingPIDs: [Int32]
    public let estimatedFreedBytes: UInt64
    public let completedAt: Date

    public init(
        incidentID: String,
        terminatedPIDs: [Int32],
        forcedPIDs: [Int32],
        survivingPIDs: [Int32],
        estimatedFreedBytes: UInt64,
        completedAt: Date = Date()
    ) {
        self.incidentID = incidentID
        self.terminatedPIDs = terminatedPIDs
        self.forcedPIDs = forcedPIDs
        self.survivingPIDs = survivingPIDs
        self.estimatedFreedBytes = estimatedFreedBytes
        self.completedAt = completedAt
    }

    public var succeeded: Bool { survivingPIDs.isEmpty }
}

public enum HeadlessGuardError: LocalizedError {
    case processListingFailed(String)
    case staleIncident
    case unsafeIncident(String)
    case cleanupFailed(String)

    public var errorDescription: String? {
        switch self {
        case .processListingFailed(let detail):
            return "Could not read the process list: \(detail)"
        case .staleIncident:
            return "The process changed after scanning. Scan again before cleaning."
        case .unsafeIncident(let detail):
            return "Safety check refused this cleanup: \(detail)"
        case .cleanupFailed(let detail):
            return "Cleanup failed: \(detail)"
        }
    }
}
