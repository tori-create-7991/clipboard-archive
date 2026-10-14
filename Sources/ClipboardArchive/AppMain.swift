import AppKit
import SwiftUI

@main
enum ClipboardArchiveMain {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let state = AppState()
    private var monitor: ClipboardMonitor?
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private let menu = NSMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.title = "📋"
        menu.delegate = self
        statusItem.menu = menu
        monitor = ClipboardMonitor(state: state)
        rebuildMenu()
    }

    func menuNeedsUpdate(_ menu: NSMenu) { rebuildMenu() }

    @objc private func toggleMonitoring() {
        state.isMonitoring.toggle()
        state.lastMessage = state.isMonitoring ? "Monitoring resumed" : "Monitoring paused"
        rebuildMenu()
    }

    @objc private func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = SettingsView(state: state) { [weak self] in self?.chooseDestination() }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Clipboard Archive"
        window.center()
        window.contentView = NSHostingView(rootView: view)
        window.isReleasedWhenClosed = false
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() { NSApp.terminate(nil) }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.title = "Choose Archive Folder"
        panel.message = "Clipboard content will be saved in this local folder."
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = state.destinationURL
        guard panel.runModal() == .OK, let url = panel.url else { return }
        state.destinationPath = url.path
        state.lastMessage = "Save folder changed"
        state.lastError = nil
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        let status = NSMenuItem(title: state.isMonitoring ? "Monitoring clipboard" : "Monitoring paused", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        let folder = NSMenuItem(title: "Saving to: \(state.destinationURL.lastPathComponent)", action: nil, keyEquivalent: "")
        folder.isEnabled = false
        menu.addItem(folder)

        let message = NSMenuItem(title: state.lastError.map { "Error: \($0)" } ?? state.lastMessage, action: nil, keyEquivalent: "")
        message.isEnabled = false
        menu.addItem(message)
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: state.isMonitoring ? "Pause Monitoring" : "Resume Monitoring", action: #selector(toggleMonitoring), keyEquivalent: "p")
        toggle.target = self
        menu.addItem(toggle)
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Clipboard Archive", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }
}

private struct SettingsView: View {
    @ObservedObject var state: AppState
    let chooseDestination: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Clipboard Archive").font(.title2.bold())
            Text(state.isMonitoring ? "Monitoring is on" : "Monitoring is paused")
                .foregroundStyle(state.isMonitoring ? Color.green : Color.secondary)
            Button(state.isMonitoring ? "Pause monitoring" : "Resume monitoring") {
                state.isMonitoring.toggle()
                state.lastMessage = state.isMonitoring ? "Monitoring resumed" : "Monitoring paused"
            }

            Divider()
            Text("Save types").font(.headline)
            Toggle("Images as PNG", isOn: $state.savesImages)
            Toggle("URLs as .webloc", isOn: $state.savesURLs)
            Toggle("Rich text (RTF / HTML)", isOn: $state.savesRichText)
            Toggle("Plain text as UTF-8 TXT", isOn: $state.savesText)
            HStack {
                Text("Finder files")
                Spacer()
                Picker("Finder files", selection: Binding(
                    get: { state.finderFileMode },
                    set: { state.finderFileMode = $0 }
                )) {
                    ForEach(FinderFileMode.allCases) { mode in Text(mode.title).tag(mode) }
                }
                .labelsHidden()
                .frame(width: 150)
            }
            Text("Record paths stores names and paths only. Copy files duplicates local items into the archive.")
                .font(.caption).foregroundStyle(.secondary)

            Divider()
            Text("Save folder").font(.headline)
            Text(state.destinationPath).font(.caption).textSelection(.enabled).lineLimit(2)
            Button("Choose folder…", action: chooseDestination)
            Text("Choose a folder that is not managed by iCloud Drive or another sync service if the archive must stay on this Mac.")
                .font(.caption).foregroundStyle(.secondary)
            Text(state.lastError.map { "Error: \($0)" } ?? state.lastMessage)
                .font(.caption).foregroundColor(state.lastError == nil ? Color.secondary : Color.red)
                .lineLimit(3)
            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(minWidth: 430, minHeight: 500)
    }
}
