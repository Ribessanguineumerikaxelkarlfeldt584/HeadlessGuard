# Privacy

Headless Guard is a local process utility. It has no analytics SDK, telemetry endpoint, account system, update checker, or network client.

## Data read

The app reads the local process table to obtain process identifiers, parent identifiers, process groups, state, CPU percentage, resident memory, elapsed time, and command lines. This data is held in memory for classification and refreshed every five seconds while the app runs.

## Data written

The app stores only these preferences in macOS user defaults:

- whether confirmed stale-orphan automatic cleanup is enabled;
- the selected stale-session age threshold.

Enabling “Launch at login” registers the app through Apple's `SMAppService` API.

## Data not accessed

Headless Guard does not read browser history, cookies, bookmarks, page contents, downloads, passwords, keychain data, or automation profile files. It does not delete profiles.

## Network

The app and CLI make no network requests. GitHub badges, release downloads, and repository pages are outside the running application's behavior.

## Diagnostics and issue reports

Command lines can contain URLs, tokens, proxy credentials, and user paths. Do not paste raw process output into a public issue. Use the structured issue forms and redact secrets first.
