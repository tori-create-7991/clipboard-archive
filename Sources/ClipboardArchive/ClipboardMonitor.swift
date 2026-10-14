import AppKit
import Foundation

final class ClipboardMonitor {
    private let state: AppState
    private var timer: Timer?
    private var lastChangeCount: Int
    private var duplicateTracker = DuplicateTracker()

    init(state: AppState) {
        self.state = state
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func poll() {
        guard state.isMonitoring else { return }
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if #available(macOS 15.4, *), pasteboard.accessBehavior == .alwaysDeny {
            state.lastError = "macOS has denied clipboard access. Review Clipboard Archive in System Settings > Privacy & Security."
            state.lastMessage = "Clipboard access is denied"
            return
        }

        var attemptedDigest: String?
        do {
            guard let payload = try payload(from: pasteboard) else {
                state.lastMessage = "Clipboard changed; no enabled supported content"
                return
            }
            let digest = DuplicateTracker.digest(Data(payload.fileExtension.utf8) + payload.data)
            guard duplicateTracker.shouldArchive(digest) else {
                state.lastMessage = "Duplicate content skipped"
                return
            }
            attemptedDigest = digest
            let writer = ArchiveWriter(directory: state.destinationURL)
            if let fileURLs = payload.fileURLs {
                for url in fileURLs { _ = try writer.copy(url) }
                state.lastMessage = "Copied \(fileURLs.count) Finder item(s)"
                state.lastError = nil
                return
            }
            let savedURL = try writer.write(payload.data, base: payload.baseName, extension: payload.fileExtension)
            state.lastMessage = "Saved \(savedURL.lastPathComponent)"
            state.lastError = nil
        } catch {
            if let attemptedDigest { duplicateTracker.remove(attemptedDigest) }
            state.lastError = error.localizedDescription
            state.lastMessage = "Could not save clipboard content"
        }
    }

    private func payload(from pasteboard: NSPasteboard) throws -> ArchivePayload? {
        if state.finderFileMode != .ignore,
           let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            let localFiles = fileURLs.filter(\.isFileURL)
            if !localFiles.isEmpty {
                switch state.finderFileMode {
                case .ignore: break
                case .reference:
                    let paths = localFiles.map(\.path).joined(separator: "\n") + "\n"
                    return ArchivePayload(data: Data(paths.utf8), baseName: localFiles[0].lastPathComponent, fileExtension: "txt")
                case .copy:
                    return ArchivePayload(data: Data(localFiles.map(\.path).joined(separator: "\n").utf8), baseName: "finder-items", fileExtension: "files", fileURLs: localFiles)
                }
            }
        }

        if state.savesImages {
            if let png = pasteboard.data(forType: .png) {
                return ArchivePayload(data: png, baseName: "image", fileExtension: "png")
            }
            if let tiff = pasteboard.data(forType: .tiff),
               let bitmap = NSBitmapImageRep(data: tiff),
               let png = bitmap.representation(using: .png, properties: [:]) {
                return ArchivePayload(data: png, baseName: "image", fileExtension: "png")
            }
        }

        if state.savesURLs {
            let rawURL = pasteboard.string(forType: .URL)
                ?? (pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL])?.first?.absoluteString
                ?? pasteboard.string(forType: .string).flatMap { candidate in
                    guard let url = URL(string: candidate), ["http", "https", "mailto", "ftp"].contains(url.scheme?.lowercased() ?? "") else { return nil }
                    return candidate
                }
            if let rawURL, let url = URL(string: rawURL), url.scheme != nil {
                return ArchivePayload(data: try ArchiveFormat.weblocData(for: url), baseName: "link", fileExtension: "webloc")
            }
        }

        if state.savesRichText {
            let rtf = NSPasteboard.PasteboardType("public.rtf")
            if let data = pasteboard.data(forType: rtf) {
                return ArchivePayload(data: data, baseName: "rich-text", fileExtension: "rtf")
            }
            let html = NSPasteboard.PasteboardType("public.html")
            if let data = pasteboard.data(forType: html) {
                return ArchivePayload(data: data, baseName: "rich-text", fileExtension: "html")
            }
        }

        if state.savesText, let text = pasteboard.string(forType: .string), !text.isEmpty {
            return ArchivePayload(data: Data(text.utf8), baseName: "text", fileExtension: "txt")
        }
        return nil
    }
}

private struct ArchivePayload {
    let data: Data
    let baseName: String
    let fileExtension: String
    var fileURLs: [URL]? = nil
}
