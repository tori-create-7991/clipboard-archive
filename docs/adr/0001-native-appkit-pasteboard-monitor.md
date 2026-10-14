# ADR 0001: Use a native AppKit pasteboard monitor

- Status: Accepted
- Date: 2026-10-09

## Context

The app needs to monitor clipboard changes locally, expose monitoring state, and avoid the Screen Recording permission path involved in the prior Shortcuts workflow.

## Decision

Implement a macOS menu bar application using AppKit and poll `NSPasteboard.general.changeCount`. Use Swift Package Manager for the source and tests, with a small script to wrap the executable as a local `.app` bundle.

## Consequences

- Clipboard access uses the macOS pasteboard APIs and remains subject to OS permission prompts and denials.
- The app can show clear pause/status/error controls in the menu bar.
- The executable is not automatically registered to launch at login and is not signed or published by this project.
- Polling can miss rapid clipboard transitions and supports only representations documented by the app.

## Alternatives

- Shortcuts automation: user-managed and tied to an undesirable screen-capture permission experience.
- Hidden LaunchAgent: makes sensitive continuous monitoring less visible and adds lifecycle management.
