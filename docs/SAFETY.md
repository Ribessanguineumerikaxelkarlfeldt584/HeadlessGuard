# Safety model

Headless Guard terminates processes, so false-positive avoidance is the primary product requirement.

## Non-negotiable protections

- Ordinary browser main processes with standard profiles are never eligible.
- Browser helpers, renderers, GPU processes, crash reporters, extensions, and native messaging hosts cannot independently create an incident.
- A single keyword, executable name, remote debugging port, or old process is never enough for automatic cleanup.
- The GUI accepts a classified session identifier, not an arbitrary PID.
- Headless Guard and its ancestor processes are excluded from every cleanup plan.
- There is no broad process-name kill and no profile deletion.

## Evidence

The classifier combines independent categories:

1. **Headless mode:** `--headless`, `--headless=new`, `-headless`, or a headless-shell executable.
2. **Isolated profile:** Playwright, Puppeteer, or Rod temporary profile conventions.
3. **Automation transport:** debugging pipe, ephemeral debugging port, or comparable framework control channel.
4. **Launcher:** a dedicated Playwright daemon, Puppeteer runner, WebDriver, Selenium, or Rod launcher ancestor.
5. **Lifecycle:** a launcher adopted by PID 1 and older than the stale threshold.

Scoring exists to explain a decision. Cleanup eligibility additionally requires hard conditions: confirmed confidence and a strong automation fingerprint on every browser root in the session.

## Cleanup state machine

1. Re-scan immediately before acting.
2. Resolve the requested root again and refuse stale or downgraded incidents.
3. Exclude Headless Guard, its ancestors, PID 0, and PID 1.
4. Send `SIGTERM` to the dedicated launcher first, then the verified browser tree.
5. Wait for the grace period.
6. Re-scan and match both PID and a bounded command fingerprint.
7. Send `SIGKILL` only to matching survivors.
8. Re-scan and return any remaining PID instead of claiming success.
9. Check for a newly classified incident after cleanup.

Version 0.1 uses elapsed time plus a command fingerprint to reduce PID-reuse risk. Direct macOS process start-time identity is planned before broader automatic policies.

## Policy modes

- **Observe:** default; scans and explains only.
- **Manual rescue:** the user confirms a preview of all eligible sessions.
- **Auto-clean confirmed orphans:** explicitly enabled; requires confirmed confidence, PID 1 adoption, and the configured minimum age.

Headed automation, manual DevTools sessions, ambiguous Chrome instances, and normal-profile automation remain observe-only in every mode.

## False positives

Treat any ordinary-process termination as safety-critical. Disable automatic cleanup, preserve the redacted evidence, and use the dedicated false-positive issue form. Do not include tokens, URLs with credentials, or private user paths.
