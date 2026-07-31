# Architecture

Headless Guard is a dependency-free Swift package with one safety core and two interfaces.

```text
Sources/
├── HeadlessGuardKit/
│   ├── ProcessScanner.swift    ps snapshot and elapsed-time parser
│   ├── ProcessDetector.swift   graph, signatures, confidence, hard policy
│   ├── ProcessCleaner.swift    revalidation and signal state machine
│   ├── Models.swift            serializable processes, incidents, results
│   └── Formatting.swift        shared presentation helpers
├── HeadlessGuardCLI/           scan, rescue, watch, doctor, JSON
└── HeadlessGuardApp/           SwiftUI dashboard, menu bar, policy controls
```

## Data flow

1. `ProcessScanner` obtains PID, PPID, PGID, state, CPU, RSS, elapsed time, and command line from one process snapshot.
2. `ProcessDetector` identifies browser roots, walks ancestors for dedicated launchers, and collects descendants into sessions.
3. Evidence contributes to an explainable score, while separate hard conditions determine cleanup eligibility.
4. The app and CLI render the same `BrowserIncident` model.
5. `ProcessCleaner` performs a fresh scan, resolves the same root, freezes eligible process fingerprints, stops the launcher first, escalates only matching survivors, and returns a structured result.

## Why native SwiftUI

The product exists to reduce hidden browser overhead. A native SwiftUI/AppKit interface adds no Chromium or Electron runtime and integrates directly with the menu bar, login items, app lifecycle, and system appearance.

## Signature extension rules

Signatures live in `ProcessDetector`. A new framework should add explicit evidence in at least two categories and tests for:

- the expected browser root and launcher tree;
- ordinary browser helpers;
- manual debugging;
- a single ambiguous signal;
- headed automation when applicable.

## Current trade-offs

Version 0.1 uses `/bin/ps` for a compact, portable snapshot. The parser is deterministic and tested, but a future release should use `proc_listallpids`, `proc_pidinfo`, `proc_pidpath`, and `KERN_PROCARGS2`, with `(pid, startTime)` as process identity. The current hard policy remains intentionally conservative until that migration lands.
