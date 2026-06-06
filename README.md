# MacOS Settings Controller

A lightweight macOS application that allows users to manage system settings, such as the default web browser, directly from the menu bar or via a local HTTP API.

## Requirements
* macOS 13.0 or later
* Swift 5.8 or later (Swift Package Manager)

## Features
* macOS status bar utility running in accessory mode (no Dock icon).
* Custom menu bar icon showcasing current default browser.
* Swift-packaged background HTTP API server on port 9090.
* Thread-safe background AppleScript automation for confirming system default handler dialogs.

## Building and Packaging

To compile and package the application into a standalone `.app` bundle with a custom icon, execute:

```bash
./package.sh path/to/app_icon.png
```

This creates `MacSettingsController.app` in the root of the project directory.

## Running the Application

To run the packaged application:

```bash
open MacSettingsController.app
```

Or execute the binary directly in the background:

```bash
./MacSettingsController.app/Contents/MacOS/MacSettingsController &
```

## Local API Endpoints

The background server runs on `http://localhost:9090` and supports:
* `GET /health` - Check if the API server is healthy.
* `GET /browsers` - List all installed web browsers and the current default browser.
* `POST /set_default` - Set the default browser. Requires a JSON payload containing the bundle identifier:
  ```json
  {
    "bundleIdentifier": "com.google.Chrome"
  }
  ```

## Verification and Testing

* Run unit tests:
  ```bash
  swift run SettingsTests
  ```
* Run integration tests:
  ```bash
  python3 integration-tests/test_api.py
  ```
