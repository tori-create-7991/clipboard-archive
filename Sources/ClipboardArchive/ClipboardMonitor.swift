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
        var cachedObjectURLs: [URL]?
        func objectURLs() -> [URL] {
            if let cachedObjectURLs { return cachedObjectURLs }
            let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] ?? []
            cachedObjectURLs = urls
            return urls
        }

        return try ArchivePayloadSelector.select(
            finderURLs: objectURLs,
            finderFileMode: state.finderFileMode,
            pngData: { state.savesImages ? pasteboard.data(forType: .png) : nil },
            tiffAsPNGData: {
                guard state.savesImages,
                      let tiff = pasteboard.data(forType: .tiff),
                      let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
                return bitmap.representation(using: .png, properties: [:])
            },
            urlString: {
                guard state.savesURLs else { return nil }
                return pasteboard.string(forType: .URL)
                    ?? objectURLs().first?.absoluteString
                    ?? pasteboard.string(forType: .string).flatMap { candidate in
                    guard let url = URL(string: candidate), ["http", "https", "mailto", "ftp"].contains(url.scheme?.lowercased() ?? "") else { return nil }
                    return candidate
                }
            },
            richTextData: { state.savesRichText ? pasteboard.data(forType: NSPasteboard.PasteboardType("public.rtf")) : nil },
            htmlData: { state.savesRichText ? pasteboard.data(forType: NSPasteboard.PasteboardType("public.html")) : nil },
            text: { state.savesText ? pasteboard.string(forType: .string) : nil }
        )
    }
}
