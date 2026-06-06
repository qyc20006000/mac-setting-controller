import Foundation
import SettingsCore

print("Starting SettingsManager unit tests...")

let manager = SettingsManager()

// Test 1: Get installed browsers
let browsers = manager.getInstalledBrowsers()
print("Found \(browsers.count) installed browsers:")
for browser in browsers {
    print(" - Name: \(browser.name), Bundle ID: \(browser.bundleIdentifier), Path: \(browser.path)")
}

assert(!browsers.isEmpty, "Installed browsers list should not be empty")
assert(browsers.contains(where: { $0.bundleIdentifier == "com.apple.Safari" }), "Safari should be in the list of installed browsers")

// Test 2: Get default browser
if let defaultBrowser = manager.getDefaultBrowser() {
    print("Current default browser: \(defaultBrowser.name) (Bundle ID: \(defaultBrowser.bundleIdentifier))")
    assert(!defaultBrowser.bundleIdentifier.isEmpty, "Default browser bundle ID should not be empty")
    assert(browsers.contains(where: { $0.bundleIdentifier == defaultBrowser.bundleIdentifier }), "Default browser must be in the list of installed browsers")
} else {
    assertionFailure("Default browser should not be nil")
}

print("All SettingsManager unit tests passed successfully!")
