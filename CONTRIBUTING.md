# Contributing to Headless Guard

Thank you for helping make browser automation safer on macOS.

## Start here

- Discuss large behavior or policy changes before implementation.
- Keep pull requests focused and explain the user-visible safety impact.
- Never add a process-name-only kill rule.
- Never add `killall`, broad `pkill`, normal-profile deletion, or arbitrary PID input to the GUI.

## Local setup

```bash
git clone https://github.com/study8677/HeadlessGuard.git
cd HeadlessGuard
swift test
swift build
```

Build the app bundle with `make app`.

## Detection changes

Every new signature must include:

1. a redacted fixture or test for the automation process tree that should match;
2. the nearest normal-browser or manual-debugging counterexample that must not match;
3. an explanation of which independent signals establish confidence;
4. whether the session is observe-only, manually cleanable, or eligible for opt-in policy cleanup.

Prefer explicit framework, isolated-profile, and automation-transport evidence. A single string such as `headless`, `node`, `Chrome`, or `remote-debugging-port` is not enough.

## Pull request checklist

- `swift test` passes.
- `swift build -c release` passes.
- `bash -n scripts/*.sh` passes.
- UI changes include a screenshot.
- New user-facing behavior is documented.
- Command lines, URLs, usernames, and tokens in fixtures are redacted.
- The PR explains the false-positive risk.

By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
