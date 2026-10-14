# Clipboard Archive

A small macOS menu bar app that saves selected clipboard content to a local folder. It has no network code, telemetry, or cloud sync. Clipboard contents can be sensitive; choose a private destination and pause or quit the app whenever you do not want it recording. A destination managed by iCloud Drive or another sync service may still be uploaded by that separate service, so choose a non-synced folder to keep the archive on this Mac.

## Build and first run

Requirements: macOS 13 or later and Xcode Command Line Tools / Swift 5.9 or later.

```sh
swift test
./scripts/build-app.sh
open "build/Clipboard Archive.app"
```

The app appears as a clipboard icon in the menu bar. It starts monitoring by default, but only archives clipboard changes made after the app starts. Open **Settings…** to choose the content types, select the local destination folder, or change Finder file handling. The default folder is `~/Library/Application Support/Clipboard Archive`.

On first programmatic access to the general pasteboard, macOS may ask whether to allow Clipboard Archive to access the clipboard. Allow or deny that request in the OS prompt; the app does not bypass it. If access was denied, change Clipboard Archive's pasteboard access in the relevant **System Settings > Privacy & Security** pane for your macOS version. Clipboard Archive does not request Screen Recording permission.

## What gets saved

For each observed clipboard change, the app saves the first enabled representation in this order:

1. Finder file URLs, if Finder handling is set to **Record paths** or **Copy files**.
2. Images as PNG (native PNG or converted from TIFF).
3. URLs as `.webloc` property lists.
4. Rich text as RTF, otherwise HTML.
5. Plain text as UTF-8 TXT.

Items use UTC timestamped names. Existing names are never overwritten; a numeric suffix is added. New archive folders are created with user-only access and generated archive files are created with owner-only read/write access. Finder copies retain the source item's file metadata and permissions. Repeated identical content is skipped during the current app session. Finder files are ignored by default; **Record paths** writes a TXT list of local paths, while **Copy files** copies the selected local files or folders into the destination. A failed read, copy, or write is shown in the menu and settings window.

## Pause, quit, and remove

- Choose **Pause Monitoring** from the menu bar item to stop reading new clipboard changes. Choose **Resume Monitoring** to continue.
- Choose **Quit Clipboard Archive** to stop the process.
- To remove the app, quit it, delete `build/Clipboard Archive.app`, and optionally delete `~/Library/Application Support/Clipboard Archive` and the `dev.toricreate.ClipboardArchive` preferences in `~/Library/Preferences`.
- The build does not install the app or register it to launch at login.

## Limitations

- Clipboard polling can miss brief intermediate contents if several changes happen between polls.
- Only the formats listed above are archived; applications may expose different representations or omit rich-text/URL data.
- The app does not archive clipboard history already present when it launches, and duplicate suppression is in-memory for one run only.
- Finder file references are local path text, not portable aliases. Copying can fail for inaccessible files or folders.
- The app is unsigned and intended for local source builds. macOS may present its normal warning for an unsigned app; this project does not weaken Gatekeeper or security settings.
- No automatic startup, installer, notarization, or distribution packaging is included.

## Project status

This repository contains an initial local implementation. No license has been selected. Do not redistribute it until the owner chooses a license and reviews the project for release.
