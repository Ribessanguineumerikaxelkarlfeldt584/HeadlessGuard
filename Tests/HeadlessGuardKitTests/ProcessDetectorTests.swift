import Darwin
import Testing
@testable import HeadlessGuardKit

@Suite("Process detection safety")
struct ProcessDetectorTests {
    private let detector = ProcessDetector()

    @Test
    func testRealPlaywrightLeakBecomesConfirmedSafeIncident() {
        let processes = [
            process(
                80_982, parent: 1, age: 202_000,
                command: "/opt/homebrew/bin/node /tmp/node_modules/playwright-core/lib/entry/cliDaemon.js mobile-audit-ddn3"
            ),
            process(
                80_983, parent: 80_982, rssMB: 58, age: 202_000,
                command: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome --headless --remote-debugging-pipe --no-startup-window --disable-blink-features=AutomationControlled --user-data-dir=/tmp/task/playwright_chromiumdev_profile-m0BHlR"
            ),
            process(
                80_989, parent: 80_983, rssMB: 20, age: 201_999,
                command: "/Applications/Google Chrome.app/Contents/Frameworks/Helpers/Google Chrome Helper (GPU).app/Contents/MacOS/Google Chrome Helper (GPU) --type=gpu-process --headless --user-data-dir=/tmp/task/playwright_chromiumdev_profile-m0BHlR"
            )
        ]

        let incidents = detector.detect(in: processes)

        #expect(incidents.count == 1)
        #expect(incidents[0].source == "Playwright · mobile-audit-ddn3")
        #expect(incidents[0].family == .chrome)
        #expect(incidents[0].rootProcess.pid == 80_982)
        #expect(incidents[0].browserProcesses.map(\.pid) == [80_983])
        #expect(incidents[0].processCount == 3)
        #expect(incidents[0].confidence == .confirmed)
        #expect(incidents[0].isOrphaned)
        #expect(incidents[0].isSafeToClean)
    }

    @Test
    func testNormalChromeAndHelpersAreHardProtected() {
        let processes = [
            process(
                35_994, parent: 1, rssMB: 220, age: 700,
                command: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome --restart"
            ),
            process(
                36_013, parent: 35_994, rssMB: 330, age: 699,
                command: "/Applications/Google Chrome.app/Contents/Frameworks/Helpers/Google Chrome Helper.app/Contents/MacOS/Google Chrome Helper --type=gpu-process"
            ),
            process(
                36_024, parent: 35_994, rssMB: 120, age: 699,
                command: "/Applications/Google Chrome.app/Contents/Frameworks/Helpers/Google Chrome Helper (Renderer).app/Contents/MacOS/Google Chrome Helper (Renderer) --type=renderer"
            )
        ]

        #expect(detector.detect(in: processes).isEmpty)
    }

    @Test
    func testManualRemoteDebuggingIsNotEligible() {
        let chrome = process(
            9_001, parent: 1, age: 10_000,
            command: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome --remote-debugging-port=9222 --user-data-dir=/Users/example/ChromeDebug"
        )
        #expect(detector.detect(in: [chrome]).isEmpty)
    }

    @Test
    func testSingleHeadlessSignalIsReviewOnly() {
        let chrome = process(
            9_101, parent: 1, age: 10_000,
            command: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome --headless"
        )
        let incidents = detector.detect(in: [chrome])
        #expect(incidents.count == 1)
        #expect(incidents[0].confidence == .likely)
        #expect(!incidents[0].isSafeToClean)
    }

    @Test
    func testPuppeteerTreeIsDetected() {
        let runner = process(
            7_000, parent: 1, age: 8_000,
            command: "/opt/homebrew/bin/node /workspace/node_modules/puppeteer/run.js"
        )
        let chrome = process(
            7_001, parent: 7_000, age: 8_000,
            command: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome --headless=new --remote-debugging-port=0 --user-data-dir=/tmp/puppeteer_dev_chrome_profile-a1"
        )
        let incidents = detector.detect(in: [runner, chrome])
        #expect(incidents.count == 1)
        #expect(incidents[0].source == "Puppeteer")
        #expect(incidents[0].isSafeToClean)
    }

    @Test
    func testHeadedPlaywrightSessionRequiresReview() {
        let runner = process(
            7_100, parent: 1, age: 8_000,
            command: "/opt/homebrew/bin/node /workspace/playwright-core/lib/entry/cliDaemon.js headed-preview"
        )
        let chrome = process(
            7_101, parent: 7_100, age: 8_000,
            command: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome --remote-debugging-pipe --user-data-dir=/tmp/playwright_chromiumdev_profile-a1"
        )
        let incidents = detector.detect(in: [runner, chrome])
        #expect(incidents.count == 1)
        #expect(incidents[0].confidence == .likely)
        #expect(!incidents[0].isSafeToClean)
    }

    @Test
    func testShellCommandMentioningHeadlessDoesNotMatch() {
        let shell = process(
            5_001, parent: 1, age: 4_000,
            command: "/bin/zsh -c ps aux | rg 'Google Chrome --headless --remote-debugging-pipe'"
        )
        #expect(detector.detect(in: [shell]).isEmpty)
    }

    @Test
    func testAnotherUsersAutomationIsNeverEligible() {
        let runner = process(
            8_000, parent: 1, age: 20_000,
            userID: UInt32(getuid()) + 1,
            command: "/opt/node playwright-core/lib/entry/cliDaemon.js foreign"
        )
        let chrome = process(
            8_001, parent: 8_000, age: 20_000,
            userID: UInt32(getuid()) + 1,
            command: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome --headless --remote-debugging-pipe --user-data-dir=/tmp/playwright_chromiumdev_profile-foreign"
        )
        #expect(detector.detect(in: [runner, chrome]).isEmpty)
    }

    @Test
    func testElapsedParserHandlesDaysHoursAndMinutes() {
        #expect(ProcessSnapshotParser.parseElapsed("02-08:02:06") == 201_726)
        #expect(ProcessSnapshotParser.parseElapsed("11:04:03") == 39_843)
        #expect(ProcessSnapshotParser.parseElapsed("04:03") == 243)
    }

    private func process(
        _ pid: Int32,
        parent: Int32,
        rssMB: UInt64 = 10,
        age: Int,
        userID: UInt32 = UInt32(getuid()),
        command: String
    ) -> SystemProcess {
        SystemProcess(
            userID: userID,
            pid: pid,
            parentPID: parent,
            processGroupID: pid,
            state: "S",
            cpuPercent: 0,
            residentBytes: rssMB * 1_024 * 1_024,
            elapsedSeconds: age,
            commandLine: command
        )
    }
}
