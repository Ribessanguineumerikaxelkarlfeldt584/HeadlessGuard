import Foundation

public struct ProcessDetector: Sendable {
    public init() {}

    public func detect(in processes: [SystemProcess]) -> [BrowserIncident] {
        let byPID = Dictionary(uniqueKeysWithValues: processes.map { ($0.pid, $0) })
        let children = Dictionary(grouping: processes, by: \.parentPID)
        let currentUserID = UInt32(getuid())
        let browserRoots = processes.filter { $0.userID == currentUserID && isBrowserRoot($0) }
        var incidentsByRoot: [Int32: BrowserIncident] = [:]

        for browser in browserRoots {
            let controller = controllerAncestor(of: browser, in: byPID)
            let assessment = assess(browser: browser, controller: controller)
            guard assessment.score >= DetectionConfidence.likely.scoreFloor else { continue }

            let root = controller ?? browser
            let tree = processTree(rootedAt: root.pid, byPID: byPID, children: children)
                .filter { $0.userID == currentUserID }
            let relatedBrowsers = browserRoots.filter { candidate in
                candidate.pid == browser.pid || tree.contains(where: { $0.pid == candidate.pid })
            }
            let orphaned = root.parentPID == 1 && root.elapsedSeconds >= 15 * 60
            let confidence: DetectionConfidence = assessment.score >= DetectionConfidence.confirmed.scoreFloor
                ? .confirmed
                : .likely
            let safe = confidence == .confirmed
                && relatedBrowsers.allSatisfy(hasStrongAutomationFingerprint)
                && root.pid != getpid()

            let incident = BrowserIncident(
                id: "\(root.pid)-\(relatedBrowsers.map(\.pid).sorted().map(String.init).joined(separator: "-"))",
                source: sourceName(controller: controller, browser: browser),
                family: family(for: browser.commandLine),
                rootProcess: root,
                browserProcesses: relatedBrowsers.sorted { $0.pid < $1.pid },
                processes: tree.sorted { $0.pid < $1.pid },
                reasons: assessment.reasons,
                score: min(100, assessment.score),
                confidence: confidence,
                isOrphaned: orphaned,
                isSafeToClean: safe
            )

            if let existing = incidentsByRoot[root.pid] {
                if incident.score > existing.score { incidentsByRoot[root.pid] = incident }
            } else {
                incidentsByRoot[root.pid] = incident
            }
        }

        return incidentsByRoot.values.sorted {
            if $0.confidence != $1.confidence { return $0.score > $1.score }
            return $0.residentBytes > $1.residentBytes
        }
    }

    public func isBrowserRoot(_ process: SystemProcess) -> Bool {
        let line = process.commandLine.lowercased()
        guard !line.contains(" --type=") && !line.contains(" helper.app/") else { return false }
        return line.contains("/contents/macos/google chrome")
            || line.contains("/contents/macos/chromium")
            || line.contains("chrome-headless-shell")
            || line.contains("/contents/macos/microsoft edge")
            || line.contains("/contents/macos/firefox")
            || (line.contains("webkit") && line.contains("--headless"))
    }

    public func isController(_ process: SystemProcess) -> Bool {
        let line = process.commandLine.lowercased()
        return line.contains("clidaemon.js")
            || line.contains("playwright-cli")
            || line.contains("playwright_cli")
            || line.contains("playwright test")
            || line.contains("puppeteer")
            || line.contains("chromedriver")
            || line.contains("selenium-manager")
            || line.contains("webdriver")
            || line.contains("rod/launcher")
    }

    public func hasStrongAutomationFingerprint(_ process: SystemProcess) -> Bool {
        let line = process.commandLine.lowercased()
        let explicitHeadless = line.contains("--headless") || line.contains("-headless")
        let isolatedProfile = line.contains("playwright_chromiumdev_profile")
            || line.contains("puppeteer_dev_chrome_profile")
            || line.contains("/rod/user-data/")
        let automationTransport = line.contains("--remote-debugging-pipe")
            || line.contains("--remote-debugging-port=0")
        return explicitHeadless || (isolatedProfile && automationTransport)
    }

    private func controllerAncestor(
        of process: SystemProcess,
        in byPID: [Int32: SystemProcess]
    ) -> SystemProcess? {
        var parentPID = process.parentPID
        var visited = Set<Int32>()
        for _ in 0..<16 {
            guard parentPID > 1,
                  !visited.contains(parentPID),
                  let parent = byPID[parentPID],
                  parent.userID == process.userID else { break }
            if isController(parent) { return parent }
            visited.insert(parentPID)
            parentPID = parent.parentPID
        }
        return nil
    }

    private func processTree(
        rootedAt rootPID: Int32,
        byPID: [Int32: SystemProcess],
        children: [Int32: [SystemProcess]]
    ) -> [SystemProcess] {
        guard let root = byPID[rootPID] else { return [] }
        var result = [root]
        var queue = children[rootPID] ?? []
        var visited: Set<Int32> = [rootPID]

        while let next = queue.first {
            queue.removeFirst()
            guard !visited.contains(next.pid) else { continue }
            visited.insert(next.pid)
            result.append(next)
            queue.append(contentsOf: children[next.pid] ?? [])
        }
        return result
    }

    private func assess(
        browser: SystemProcess,
        controller: SystemProcess?
    ) -> (score: Int, reasons: [DetectionReason]) {
        let line = browser.commandLine.lowercased()
        var reasons: [DetectionReason] = []

        if line.contains("--headless") || line.contains("-headless") {
            reasons.append(.init(title: "Headless mode", detail: "Browser was launched without a visible window", score: 50))
        }
        if line.contains("playwright_chromiumdev_profile") {
            reasons.append(.init(title: "Playwright profile", detail: "Uses an isolated Playwright temporary profile", score: 25))
        } else if line.contains("puppeteer_dev_chrome_profile") {
            reasons.append(.init(title: "Puppeteer profile", detail: "Uses an isolated Puppeteer temporary profile", score: 25))
        } else if line.contains("/rod/user-data/") {
            reasons.append(.init(title: "Rod profile", detail: "Uses a temporary Rod automation profile", score: 30))
        }
        if line.contains("--remote-debugging-pipe") {
            reasons.append(.init(title: "Automation pipe", detail: "Controlled through a private debugging pipe", score: 10))
        } else if line.contains("--remote-debugging-port=0") {
            reasons.append(.init(title: "Automation port", detail: "Uses an ephemeral debugging port", score: 10))
        }
        if line.contains("automationcontrolled") {
            reasons.append(.init(title: "Automation flags", detail: "Browser automation fingerprints are present", score: 5))
        }
        if let controller {
            reasons.append(.init(title: "Automation launcher", detail: controller.shortCommand, score: 20))
            if controller.parentPID == 1 && controller.elapsedSeconds >= 15 * 60 {
                reasons.append(.init(title: "Detached launcher", detail: "Launcher is adopted by launchd and has outlived its caller", score: 10))
            }
        } else if browser.parentPID == 1 && browser.elapsedSeconds >= 15 * 60 {
            reasons.append(.init(title: "Detached browser", detail: "Browser is adopted by launchd and has no active caller", score: 10))
        }

        return (reasons.reduce(0) { $0 + $1.score }, reasons)
    }

    private func sourceName(controller: SystemProcess?, browser: SystemProcess) -> String {
        guard let controller else { return family(for: browser.commandLine).rawValue }
        let lower = controller.commandLine.lowercased()
        if lower.contains("clidaemon.js") {
            let tokens = controller.commandLine.split(whereSeparator: \.isWhitespace)
            if let last = tokens.last, !last.lowercased().contains("clidaemon.js") {
                return "Playwright · \(last)"
            }
            return "Playwright"
        }
        if lower.contains("puppeteer") { return "Puppeteer" }
        if lower.contains("chromedriver") || lower.contains("webdriver") { return "WebDriver" }
        if lower.contains("rod/") { return "Rod" }
        if lower.contains("playwright") { return "Playwright" }
        return controller.shortCommand
    }

    private func family(for commandLine: String) -> BrowserFamily {
        let line = commandLine.lowercased()
        if line.contains("microsoft edge") { return .edge }
        if line.contains("firefox") { return .firefox }
        if line.contains("webkit") { return .webkit }
        if line.contains("google chrome") || line.contains("chrome-headless-shell") { return .chrome }
        if line.contains("chromium") { return .chromium }
        return .unknown
    }
}
