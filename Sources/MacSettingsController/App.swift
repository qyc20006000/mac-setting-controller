import AppKit
import SettingsCore
import SwiftUI

extension NSImage {
    func resized(to newSize: NSSize) -> NSImage {
        let image = NSImage(size: newSize)
        image.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: newSize),
                  from: NSRect(origin: .zero, size: self.size),
                  operation: .copy,
                  fraction: 1.0)
        image.unlockFocus()
        return image
    }
}

@MainActor
public final class AppState: ObservableObject {
    @Published public var defaultBrowser: BrowserInfo? = nil
    @Published public var browsers: [BrowserInfo] = []
    
    private let manager = SettingsManager()
    private var timer: Timer?
    
    public init() {
        update()
        
        // Poll every 1.5 seconds on the main queue to keep settings reactively updated
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            DispatchQueue.main.async {
                self.update()
            }
        }
    }
    
    public func update() {
        let currentDefault = manager.getDefaultBrowser()
        let allBrowsers = manager.getInstalledBrowsers()
        
        if currentDefault != self.defaultBrowser {
            self.defaultBrowser = currentDefault
        }
        if allBrowsers != self.browsers {
            self.browsers = allBrowsers
        }
    }
    
    public func setDefaultBrowser(_ bundleId: String) {
        manager.setDefaultBrowser(bundleIdentifier: bundleId) { [weak self] error in
            if let error = error {
                print("Error setting default browser: \(error.localizedDescription)")
            } else {
                DispatchQueue.main.async {
                    self?.update()
                }
            }
        }
    }
}

@main
struct MacSettingsControllerApp: App {
    @StateObject private var state = AppState()
    private let server: SettingsServer
    
    init() {
        // Run as accessory app (no Dock icon)
        NSApplication.shared.setActivationPolicy(.accessory)
        
        let manager = SettingsManager()
        do {
            let server = try SettingsServer(port: 9090, manager: manager)
            server.start()
            self.server = server
        } catch {
            print("Failed to start API server: \(error)")
            fatalError("Could not start API server")
        }
    }
    
    var body: some Scene {
        let defaultBrowserName = state.defaultBrowser?.name ?? "Settings"
        
        let preferredBundleIDs = [
            "com.google.Chrome",
            "com.apple.Safari",
            "company.thebrowser.Browser"
        ]
        
        let preferredBrowsers = preferredBundleIDs.compactMap { bundleID in
            state.browsers.first { $0.bundleIdentifier == bundleID }
        }
        
        let remainingBrowsers = state.browsers.filter { !preferredBundleIDs.contains($0.bundleIdentifier) }
        
        let orderedBrowsers = preferredBrowsers + remainingBrowsers
        
        let menuIcon: Image
        if let path = Bundle.main.path(forResource: "MenuIcon", ofType: "png"),
           let nsImage = NSImage(contentsOfFile: path) {
            // Keep the custom colors of the icon
            nsImage.isTemplate = false
            menuIcon = Image(nsImage: nsImage.resized(to: NSSize(width: 18, height: 18)))
        } else {
            menuIcon = Image(systemName: "slider.horizontal.3")
        }
        
        return MenuBarExtra {
            Text("Mac Settings Controller")
                .font(.headline)
            
            Divider()
            
            Picker(selection: Binding(
                get: { state.defaultBrowser?.bundleIdentifier ?? "" },
                set: { state.setDefaultBrowser($0) }
            )) {
                ForEach(orderedBrowsers, id: \.bundleIdentifier) { browser in
                    HStack {
                        let icon = NSWorkspace.shared.icon(forFile: browser.path).resized(to: NSSize(width: 16, height: 16))
                        Image(nsImage: icon)
                        Text(browser.name)
                    }.tag(browser.bundleIdentifier)
                }
            } label: {
                if let defaultBrowser = state.defaultBrowser {
                    let icon = NSWorkspace.shared.icon(forFile: defaultBrowser.path).resized(to: NSSize(width: 16, height: 16))
                    Text("Default Browser: ") + Text(Image(nsImage: icon)) + Text(" \(defaultBrowserName)")
                } else {
                    Text("Default Browser: \(defaultBrowserName)")
                }
            }
            
            Divider()
            
            Button("About MacSettingsController") {
                let alert = NSAlert()
                alert.messageText = "About MacSettingsController"
                
                var aboutText = "Version v0.1\n\nA lightweight utility to manage system settings from the menu bar."
                if let path = Bundle.main.path(forResource: "About", ofType: "md"),
                   let content = try? String(contentsOfFile: path, encoding: .utf8) {
                    aboutText = content
                }
                
                alert.informativeText = aboutText
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            menuIcon
        }
    }
}
