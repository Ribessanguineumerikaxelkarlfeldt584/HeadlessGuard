# Changelog

All notable changes to Headless Guard are documented here. The project follows [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-07-31

### Added

- Native SwiftUI dashboard and menu bar status for macOS 13+.
- Process-tree detection for Playwright, Puppeteer, Rod, WebDriver, and Selenium fingerprints.
- Explainable confidence scoring with ordinary-browser hard protection.
- Safe `TERM → revalidate → KILL survivors` cleanup state machine.
- CLI commands for scan, explain, JSON output, dry-run rescue, watch, and diagnostics.
- Opt-in stale-orphan guard policy and launch-at-login control.
- Real Playwright leak regression fixture plus normal Chrome counterexamples.

### Security

- Cleanup refuses ambiguous, headed, normal-profile, or current-process trees.
- No broad Chrome process termination and no profile deletion.

[0.1.0]: https://github.com/study8677/HeadlessGuard/releases/tag/v0.1.0
