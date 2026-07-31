# Troubleshooting

## Chrome opens but no window appears

Run:

```bash
headless-guard scan --explain
```

If a confirmed session appears, preview with `headless-guard rescue --dry-run`, then apply with `headless-guard rescue --yes`. The command will report whether a classified session reappeared.

## A session is “Review only”

Headless Guard does not have enough independent evidence to terminate it safely. Do not work around this with `killall Chrome`. If the process is known automation, submit a missed-detection report with redacted evidence.

## A session comes back

The browser has a supervisor outside the detected tree. Stop retrying to avoid a kill loop. Inspect the launcher name, parent process, task runner, CI agent, editor integration, or long-running automation service. A recurring generic parent must be reviewed manually because it may own unrelated work.

## The list is clear but the Mac is still slow

Headless Guard handles one failure mode. Check:

- Chrome → Window → Task Manager for heavy ordinary tabs and extensions;
- Activity Monitor → Memory Pressure;
- virtual machines and containers;
- development servers, media applications, and Electron apps;
- swap usage after very long system uptime.

Do not infer that an empty Headless Guard list means system memory is healthy.

## First launch is blocked

Version 0.1.0 is ad-hoc signed but not Apple-notarized. Right-click **Headless Guard.app**, choose **Open**, and confirm once. Building locally with `make install` is another option.

## Login item cannot be enabled

Launch-at-login registration works only from a correctly packaged `.app`. Do not run the raw `HeadlessGuardApp` executable from `.build`; use `make app` or the release archive.

## Collect safe diagnostics

```bash
headless-guard doctor
headless-guard scan --explain
```

Before posting output, remove usernames, project paths, target URLs, proxy credentials, tokens, and cookies. Command lines are sensitive.
