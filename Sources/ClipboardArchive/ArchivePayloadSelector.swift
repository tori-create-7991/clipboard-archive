import Foundation

struct ArchivePayload {
    let data: Data
    let baseName: String
    let fileExtension: String
    var fileURLs: [URL]? = nil
}

enum ArchivePayloadSelector {
    static func select(
        finderURLs: () -> [URL],
        finderFileMode: FinderFileMode,
        pngData: () -> Data?,
        tiffAsPNGData: () -> Data?,
        urlString: () -> String?,
        richTextData: () -> Data?,
        htmlData: () -> Data?,
        text: () -> String?
    ) throws -> ArchivePayload? {
        let localFiles = finderFileMode == .ignore ? [] : finderURLs().filter(\.isFileURL)
        if !localFiles.isEmpty {
            switch finderFileMode {
            case .ignore:
                break
            case .reference:
                let paths = localFiles.map(\.path).joined(separator: "\n") + "\n"
                return ArchivePayload(data: Data(paths.utf8), baseName: localFiles[0].lastPathComponent, fileExtension: "txt")
            case .copy:
                let paths = localFiles.map(\.path).joined(separator: "\n")
                return ArchivePayload(data: Data(paths.utf8), baseName: "finder-items", fileExtension: "files", fileURLs: localFiles)
            }
        }

        if let png = pngData() {
            return ArchivePayload(data: png, baseName: "image", fileExtension: "png")
        }
        if let tiffAsPNG = tiffAsPNGData() {
            return ArchivePayload(data: tiffAsPNG, baseName: "image", fileExtension: "png")
        }

        if let urlString = urlString(),
           let url = URL(string: urlString),
           url.scheme != nil,
           !(finderFileMode == .ignore && url.isFileURL) {
            return ArchivePayload(data: try ArchiveFormat.weblocData(for: url), baseName: "link", fileExtension: "webloc")
        }

        if let richText = richTextData() {
            return ArchivePayload(data: richText, baseName: "rich-text", fileExtension: "rtf")
        }
        if let html = htmlData() {
            return ArchivePayload(data: html, baseName: "rich-text", fileExtension: "html")
        }

        if let text = text(), !text.isEmpty {
            return ArchivePayload(data: Data(text.utf8), baseName: "text", fileExtension: "txt")
        }
        return nil
    }
}
