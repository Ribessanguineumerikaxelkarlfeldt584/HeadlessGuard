import AppKit
import Foundation
import HeadlessGuardKit
import ServiceManagement

@MainActor
final class GuardViewModel: ObservableObject {
    static let shared = GuardViewModel()

    @Published var incidents: [BrowserIncident] = []
    @Published var lastScan: Date?
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var notice: Notice?
    @Published var autoCleanEnabled: Bool {
        didSet { UserDefaults.standard.set(autoCleanEnabled, forKey: "autoCleanEnabled") }
    }
    @Published var staleThresholdMinutes: Int {
        didSet { UserDefaults.standard.set(staleThresholdMinutes, forKey: "staleThresholdMinutes") }
    }
    @Published var launchAtLogin = false

    struct Notice: Identifiable, Equatable {
        enum Kind { case success, warning, error }
        let id = UUID()
        let kind: Kind
        let title: String
        let detail: String
    }

    private let scanner = ProcessScanner()
    private let detector = ProcessDetector()
    private let cleaner = ProcessCleaner()
    private var monitorTask: Task<Void, Never>?
    private var cleanedRoots = Set<Int32>()

    init() {
        autoCleanEnabled = UserDefaults.standard.bool(forKey: "autoCleanEnabled")
        let savedThreshold = UserDefaults.standard.integer(forKey: "staleThresholdMinutes")
        staleThresholdMinutes = savedThreshold >= 15 ? savedThreshold : 120
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    deinit { monitorTask?.cancel() }

    var confirmedIncidents: [BrowserIncident] { incidents.filter(\.isSafeToClean) }
    var reclaimableBytes: UInt64 { confirmedIncidents.reduce(0) { $0 + $1.residentBytes } }
    var totalProcessCount: Int { incidents.reduce(0) { $0 + $1.processCount } }
    var oldestAge: Int { incidents.map(\.elapsedSeconds).max() ?? 0 }

    func startMonitoring() async {
        guard monitorTask == nil else { return }
        await refresh()
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard let self else { break }
                await self.refresh()
            }
        }
    }

    func refresh() async {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }
        do {
            let snapshot = try scanner.snapshot()
            incidents = detector.detect(in: snapshot)
            lastScan = Date()
            await runAutomaticPolicyIfNeeded()
        } catch {
            notice = .init(kind: .error, title: Copy.text("扫描失败", "Scan failed"), detail: error.localizedDescription)
        }
    }

    func rescueConfirmed(openChrome: Bool = true) {
        guard !isCleaning else { return }
        let targets = confirmedIncidents
        guard !targets.isEmpty else { return }
        isCleaning = true

        Task {
            var freed: UInt64 = 0
            var failures: [String] = []
            for incident in targets {
                do {
                    let result = try await cleaner.clean(incident)
                    freed += result.estimatedFreedBytes
                    cleanedRoots.insert(incident.rootProcess.pid)
                    if !result.succeeded {
                        failures.append(result.survivingPIDs.map(String.init).joined(separator: ", "))
                    }
                } catch {
                    failures.append(error.localizedDescription)
                }
            }

            await refresh()
            isCleaning = false
            if failures.isEmpty && confirmedIncidents.isEmpty {
                notice = .init(
                    kind: .success,
                    title: Copy.text("浏览器通道已恢复", "Browser access restored"),
                    detail: Copy.text("已释放约 \(GuardFormatting.bytes(freed))，普通 Chrome 未被触碰。", "Reclaimed about \(GuardFormatting.bytes(freed)). Ordinary Chrome was not touched.")
                )
                if openChrome { launchChrome() }
            } else {
                notice = .init(
                    kind: .warning,
                    title: Copy.text("仍需检查复活源", "A launcher still needs attention"),
                    detail: failures.joined(separator: " · ")
                )
            }
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            notice = .init(kind: .error, title: Copy.text("无法更改登录项", "Could not change login item"), detail: error.localizedDescription)
        }
    }

    func launchChrome() {
        let url = URL(fileURLWithPath: "/Applications/Google Chrome.app")
        guard FileManager.default.fileExists(atPath: url.path) else {
            notice = .init(kind: .warning, title: Copy.text("未找到 Chrome", "Chrome was not found"), detail: url.path)
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, error in
            if let error {
                Task { @MainActor in
                    self.notice = .init(kind: .error, title: Copy.text("打开失败", "Could not open Chrome"), detail: error.localizedDescription)
                }
            }
        }
    }

    private func runAutomaticPolicyIfNeeded() async {
        guard autoCleanEnabled, !isCleaning else { return }
        let candidate = confirmedIncidents.first {
            $0.isOrphaned
                && $0.elapsedSeconds >= staleThresholdMinutes * 60
                && !cleanedRoots.contains($0.rootProcess.pid)
        }
        guard let candidate else { return }

        cleanedRoots.insert(candidate.rootProcess.pid)
        do {
            let result = try await cleaner.clean(candidate)
            notice = result.succeeded
                ? .init(kind: .success, title: Copy.text("已自动收尾", "Automatic cleanup complete"), detail: candidate.source)
                : .init(kind: .warning, title: Copy.text("自动收尾未完成", "Automatic cleanup incomplete"), detail: candidate.source)
        } catch {
            notice = .init(kind: .error, title: Copy.text("自动收尾失败", "Automatic cleanup failed"), detail: error.localizedDescription)
        }
    }
}

enum Copy {
    static let isChinese = Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true
    static func text(_ zh: String, _ en: String) -> String { isChinese ? zh : en }
}
