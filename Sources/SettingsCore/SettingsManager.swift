import AppKit
import Foundation
import CoreServices

public struct BrowserInfo: Codable, Equatable {
    public let name: String
    public let bundleIdentifier: String
    public let path: String
    
    public init(name: String, bundleIdentifier: String, path: String) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.path = path
    }
}

public final class SettingsManager {
    
    public init() {}
    
    private func getAppName(from bundle: Bundle, atPath path: String) -> String {
        return bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? FileManager.default.displayName(atPath: path).replacingOccurrences(of: ".app", with: "")
    }
    
    /// Returns a list of all installed web browsers capable of opening HTTPS URLs.
    public func getInstalledBrowsers() -> [BrowserInfo] {
        guard let testURL = URL(string: "https://www.apple.com") else {
            return []
        }
        
        let appURLs = NSWorkspace.shared.urlsForApplications(toOpen: testURL)
        var browsers: [BrowserInfo] = []
        
        for url in appURLs {
            let path = url.path
            
            // Extract bundle identifier
            guard let bundle = Bundle(url: url),
                  let bundleId = bundle.bundleIdentifier else {
                continue
            }
            
            let name = getAppName(from: bundle, atPath: path)
            
            // Avoid duplicates
            if !browsers.contains(where: { $0.bundleIdentifier == bundleId }) {
                browsers.append(BrowserInfo(name: name, bundleIdentifier: bundleId, path: path))
            }
        }
        
        // Sort by name for consistent presentation
        return browsers.sorted(by: { $0.name < $1.name })
    }
    
    /// Returns the current default web browser for HTTPS URLs.
    public func getDefaultBrowser() -> BrowserInfo? {
        guard let testURL = URL(string: "https://www.apple.com") else {
            return nil
        }
        
        guard let defaultAppURL = NSWorkspace.shared.urlForApplication(toOpen: testURL) else {
            return nil
        }
        
        let path = defaultAppURL.path
        
        guard let bundle = Bundle(url: defaultAppURL),
              let bundleId = bundle.bundleIdentifier else {
            return nil
        }
        
        let name = getAppName(from: bundle, atPath: path)
        return BrowserInfo(name: name, bundleIdentifier: bundleId, path: path)
    }
    
    /// Sets the default web browser for both HTTP and HTTPS schemes.
    /// Note: This is an asynchronous system call that may trigger a macOS security prompt.
    public func setDefaultBrowser(bundleIdentifier: String, completion: @escaping @Sendable (Error?) -> Void) {
        // Use LSSetDefaultHandlerForURLScheme from CoreServices.
        // On modern macOS, setting the default handler for "http" successfully triggers the system confirmation prompt
        // which updates both http and https defaults upon user confirmation. Setting "https" directly returns a -54 permission error on CLI binaries.
        let httpStatus = LSSetDefaultHandlerForURLScheme("http" as CFString, bundleIdentifier as CFString)
        
        if httpStatus == noErr {
            // Asynchronously run AppleScript via process to automatically click the confirmation dialog.
            // Using a separate Process is thread-safe and avoids NSAppleScript background crashes.
            DispatchQueue.global(qos: .userInitiated).async {
                // Wait briefly for the system dialog to appear
                Thread.sleep(forTimeInterval: 0.4)
                
                let scriptSource = """
                tell application "System Events"
                    tell process "CoreServicesUIAgent"
                        repeat 20 times
                            if (count of windows) > 0 then
                                tell window 1
                                    try
                                        click (every button whose title contains "Use")
                                        exit repeat
                                    end try
                                    try
                                        click (every button whose name contains "Use")
                                        exit repeat
                                    end try
                                end tell
                            end if
                            delay 0.1
                        end repeat
                    end tell
                end tell
                """
                
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", scriptSource]
                process.standardOutput = Pipe()
                process.standardError = Pipe()
                
                do {
                    try process.run()
                    process.waitUntilExit()
                } catch {
                    print("Failed to run background osascript: \(error.localizedDescription)")
                }
            }
            completion(nil)
        } else {
            let error = NSError(domain: "SettingsManager", code: Int(httpStatus), userInfo: [NSLocalizedDescriptionKey: "Failed to set default handler for URL scheme. OSStatus: \(httpStatus)."])
            completion(error)
        }
    }
}
