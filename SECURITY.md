# Security policy

## Supported versions

Security fixes are provided for the latest published release and the current `main` branch.

| Version | Supported |
| --- | --- |
| 0.1.x | Yes |
| Earlier | No |

## Report a vulnerability

Use [GitHub private vulnerability reporting](https://github.com/study8677/HeadlessGuard/security/advisories/new). Do not open a public issue for vulnerabilities.

Relevant security reports include:

- a false positive that can terminate an ordinary browser or unrelated process;
- PID reuse, process-tree confusion, or launcher spoofing that bypasses cleanup safeguards;
- unintended access to browser profiles, secrets, or another user's processes;
- privilege escalation, arbitrary signal targets, or command injection;
- sensitive command-line data written to disk or sent over the network.

Please include the affected version, macOS version, architecture, minimal redacted reproduction, expected result, and observed result. Never include live tokens, cookies, proxy credentials, or unredacted private paths.

You should receive an initial response within seven days. A coordinated disclosure timeline will be agreed after validation.

## Permission boundary

Headless Guard does not require administrator access, Accessibility, Full Disk Access, or browser extensions. It reads process metadata available to the current user and sends signals only after the safety classifier approves a same-user automation tree. The app has no network or telemetry code.

## Release verification

Each release includes `SHA256SUMS.txt`. Version 0.1.0 is ad-hoc signed for structural integrity but is not Apple-notarized; this limitation is stated in the release notes and README.
