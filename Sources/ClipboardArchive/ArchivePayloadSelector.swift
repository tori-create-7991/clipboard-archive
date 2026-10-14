import Foundation

struct ArchivePayload {
    let data: Data
    let baseName: String
    let fileExtension: String
    var fileURLs: [URL]? = nil
}

enum ArchivePayloadSelector {
    static func select(
        finderURLs: [URL],
        finderFileMode: FinderFileMode,
        pngData: Data?,
        tiffAsPNGData: Data?,
        urlString: String?,
        richTextData: Data?,
        htmlData: Data?,
        text: String?
    ) throws -> ArchivePayload? {
        let localFiles = finderURLs.filter(\.isFileURL)
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

        if let pngData {
            return ArchivePayload(data: pngData, baseName: "image", fileExtension: "png")
        }
        if let tiffAsPNGData {
            return ArchivePayload(data: tiffAsPNGData, baseName: "image", fileExtension: "png")
        }

        if let urlString, let url = URL(string: urlString), url.scheme != nil {
            return ArchivePayload(data: try ArchiveFormat.weblocData(for: url), baseName: "link", fileExtension: "webloc")
        }

        if let richTextData {
            return ArchivePayload(data: richTextData, baseName: "rich-text", fileExtension: "rtf")
        }
        if let htmlData {
            return ArchivePayload(data: htmlData, baseName: "rich-text", fileExtension: "html")
        }

        if let text, !text.isEmpty {
            return ArchivePayload(data: Data(text.utf8), baseName: "text", fileExtension: "txt")
        }
        return nil
    }
}
