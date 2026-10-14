import Combine
import Foundation

enum FinderFileMode: Int, CaseIterable, Identifiable {
    case ignore
    case reference
    case copy

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .ignore: "Ignore"
        case .reference: "Record paths"
        case .copy: "Copy files"
        }
    }
}

final class AppState: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var isMonitoring: Bool {
        didSet { defaults.set(isMonitoring, forKey: "isMonitoring") }
    }
    @Published var savesImages: Bool {
        didSet { defaults.set(savesImages, forKey: "savesImages") }
    }
    @Published var savesURLs: Bool {
        didSet { defaults.set(savesURLs, forKey: "savesURLs") }
    }
    @Published var savesRichText: Bool {
        didSet { defaults.set(savesRichText, forKey: "savesRichText") }
    }
    @Published var savesText: Bool {
        didSet { defaults.set(savesText, forKey: "savesText") }
    }
    @Published var finderFileMode: FinderFileMode {
        didSet { defaults.set(finderFileMode.rawValue, forKey: "finderFileMode") }
    }
    @Published var destinationPath: String {
        didSet { defaults.set(destinationPath, forKey: "destinationPath") }
    }
    @Published var lastMessage = "Waiting for a clipboard change"
    @Published var lastError: String?

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Clipboard Archive", isDirectory: true)
        isMonitoring = defaults.object(forKey: "isMonitoring") as? Bool ?? true
        savesImages = defaults.object(forKey: "savesImages") as? Bool ?? true
        savesURLs = defaults.object(forKey: "savesURLs") as? Bool ?? true
        savesRichText = defaults.object(forKey: "savesRichText") as? Bool ?? true
        savesText = defaults.object(forKey: "savesText") as? Bool ?? true
        finderFileMode = FinderFileMode(rawValue: defaults.integer(forKey: "finderFileMode")) ?? .ignore
        destinationPath = defaults.string(forKey: "destinationPath") ?? support.path
    }

    var destinationURL: URL { URL(fileURLWithPath: destinationPath, isDirectory: true) }
}
