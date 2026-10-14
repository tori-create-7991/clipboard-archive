import CryptoKit
import Darwin
import Foundation

enum ArchiveFormat {
    static func weblocData(for url: URL) throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: ["URL": url.absoluteString],
            format: .xml,
            options: 0
        )
    }
}

enum ArchiveNaming {
    static func filename(base: String, extension fileExtension: String, date: Date, collision: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"

        let safeBase = base
            .components(separatedBy: CharacterSet(charactersIn: "/\\:\n\r\0"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBase = String((safeBase.isEmpty ? "clipboard" : safeBase).prefix(80))
        let suffix = collision == 0 ? "" : "-\(collision)"
        return "\(formatter.string(from: date))_\(trimmedBase)\(suffix).\(fileExtension)"
    }
}

struct DuplicateTracker {
    private var digests = Set<String>()
    private var order: [String] = []
    private let capacity: Int

    init(capacity: Int = 500) {
        self.capacity = max(capacity, 1)
    }

    mutating func shouldArchive(_ digest: String) -> Bool {
        guard !digests.contains(digest) else { return false }
        digests.insert(digest)
        order.append(digest)
        if order.count > capacity {
            digests.remove(order.removeFirst())
        }
        return true
    }

    mutating func remove(_ digest: String) {
        guard digests.remove(digest) != nil else { return }
        order.removeAll { $0 == digest }
    }

    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

struct ArchiveWriter {
    let directory: URL
    private let fileManager = FileManager.default

    func write(_ data: Data, base: String, extension fileExtension: String, date: Date = Date()) throws -> URL {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        for collision in 0..<10_000 {
            let filename = ArchiveNaming.filename(base: base, extension: fileExtension, date: date, collision: collision)
            let destination = directory.appendingPathComponent(filename)
            let descriptor = destination.path.withCString { open($0, O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR) }
            if descriptor == -1 {
                if errno == EEXIST { continue }
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            do {
                try writeAll(data, to: descriptor)
                _ = close(descriptor)
                return destination
            } catch {
                _ = close(descriptor)
                try? fileManager.removeItem(at: destination)
                throw error
            }
        }
        throw ArchiveError.tooManyFilenameCollisions
    }

    func copy(_ source: URL, date: Date = Date()) throws -> URL {
        let isDirectory = (try? source.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        let fileExtension = source.pathExtension.isEmpty ? (isDirectory ? "folder" : "file") : source.pathExtension
        let base = source.deletingPathExtension().lastPathComponent
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        for collision in 0..<10_000 {
            let filename = ArchiveNaming.filename(base: base, extension: fileExtension, date: date, collision: collision)
            let destination = directory.appendingPathComponent(filename, isDirectory: isDirectory)
            do {
                try fileManager.copyItem(at: source, to: destination)
                return destination
            } catch let error as CocoaError where error.code == .fileWriteFileExists {
                continue
            }
        }
        throw ArchiveError.tooManyFilenameCollisions
    }

    private func writeAll(_ data: Data, to descriptor: Int32) throws {
        try data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            var offset = 0
            while offset < rawBuffer.count {
                let written = Darwin.write(descriptor, baseAddress.advanced(by: offset), rawBuffer.count - offset)
                if written < 0 {
                    if errno == EINTR { continue }
                    throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
                }
                offset += written
            }
        }
    }
}

enum ArchiveError: Error {
    case tooManyFilenameCollisions
}
