# Clipboard Archive Design

## Context and scope

Clipboard Archive is a local macOS menu bar application that archives selected clipboard content to user-chosen storage. Clipboard data can contain sensitive information, so clipboard reads and writes stay on the Mac, the app makes its monitoring state and destination visible, and the app uses the system clipboard API without bypassing macOS permissions.

## Goals

- Poll `NSPasteboard.changeCount` while monitoring is enabled.
- Save selected image, URL, rich-text, plain-text, and Finder file representations with timestamped names.
- Allow Finder file representations to be ignored, recorded as a local path reference, or copied.
- Suppress repeat saves and avoid overwriting existing files.
- Provide pause/resume, type selection, destination selection, and visible errors from a menu bar UI.
- Document first launch, permissions, limitations, stopping, and removal.

## Non-goals

- Cloud sync, networking, account systems, or telemetry.
- Capturing screenshots or accessing screen recording permissions.
- Registering automatic login launch, installing the app, signing, or publishing it.
- Preserving every pasteboard flavor or arbitrary application-specific binary formats.

## Design

The AppKit application owns a status item and settings window. A monitor polls the general pasteboard at a short interval and compares `changeCount`; it reads only when the count changes and monitoring is enabled. A content selector uses the first enabled supported representation in a documented priority order (Finder file URLs, image, URL, RTF, HTML, plain text) to avoid archiving multiple equivalent flavors from one copy operation. The archive writer sanitizes names, appends a stable timestamp and collision counter, writes atomically, and tracks recent content hashes for duplicate suppression. URL values use `.webloc` property lists; text uses UTF-8 `.txt`; images use PNG; RTF and HTML retain their source representation.

The default destination is a dedicated folder under the user's Application Support directory. The user can select another folder through the standard folder picker. Finder file handling is disabled by default; reference mode writes the selected local paths to a `.txt` record, while copy mode copies selected files into an archive subfolder. Failures are surfaced in the menu and settings window; the monitor continues with later clipboard changes.

```text
NSPasteboard changeCount -> Monitor -> Selected representation -> Archive writer -> Local folder
                                        Settings UI <-> UserDefaults
```

## Alternatives considered

- **AppKit menu bar app (selected):** Native system APIs, direct permission behavior, small local runtime, no screen capture.
- **Shortcuts automation:** Depends on user-managed automation and can encounter Screen Recording permission flows; unsuitable for continuous clipboard history.
- **Background launch agent:** Can monitor without a visible app, but hides sensitive monitoring state and adds registration/removal complexity.

## Risks and constraints

- macOS may require user approval for clipboard access; the app must not work around a denial.
- Pasteboard change polling is not an immutable event log and may miss content replaced before the next poll.
- File URLs may be unavailable or access may fail; such failures are reported and no file contents are read for reference mode.
- RTF/HTML support depends on the source application exposing those pasteboard types.

## Success criteria

- `swift test` passes for format selection, duplicate suppression, collision-safe naming, and URL serialization.
- `swift build` succeeds on macOS.
- README describes permissions, first setup, destination, pause/removal, and format limitations.
