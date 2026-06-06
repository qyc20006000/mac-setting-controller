#!/bin/bash
set -e

# Define directories
PROJECT_DIR="$(pwd)"
APP_NAME="MacSettingsController"
APP_BUNDLE="${PROJECT_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
PNG_ICON="$1"

echo "Building Swift project in release mode..."
swift build -c release

# Remove existing bundle if it exists
if [ -d "${APP_BUNDLE}" ]; then
    echo "Cleaning old application bundle..."
    rm -rf "${APP_BUNDLE}"
fi

echo "Scaffolding .app bundle structure..."
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

echo "Copying compiled binary..."
cp "${PROJECT_DIR}/.build/release/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# Generate ICNS if PNG icon is provided
HAS_ICON=false
if [ -n "${PNG_ICON}" ] && [ -f "${PNG_ICON}" ]; then
    echo "Generating ICNS app icon from PNG: ${PNG_ICON}..."
    ICONSET_DIR="${PROJECT_DIR}/${APP_NAME}.iconset"
    mkdir -p "${ICONSET_DIR}"
    
    sips -s format png -z 16 16     "${PNG_ICON}" --out "${ICONSET_DIR}/icon_16x16.png" > /dev/null 2>&1
    sips -s format png -z 32 32     "${PNG_ICON}" --out "${ICONSET_DIR}/icon_16x16@2x.png" > /dev/null 2>&1
    sips -s format png -z 32 32     "${PNG_ICON}" --out "${ICONSET_DIR}/icon_32x32.png" > /dev/null 2>&1
    sips -s format png -z 64 64     "${PNG_ICON}" --out "${ICONSET_DIR}/icon_32x32@2x.png" > /dev/null 2>&1
    sips -s format png -z 128 128   "${PNG_ICON}" --out "${ICONSET_DIR}/icon_128x128.png" > /dev/null 2>&1
    sips -s format png -z 256 256   "${PNG_ICON}" --out "${ICONSET_DIR}/icon_128x128@2x.png" > /dev/null 2>&1
    sips -s format png -z 256 256   "${PNG_ICON}" --out "${ICONSET_DIR}/icon_256x256.png" > /dev/null 2>&1
    sips -s format png -z 512 512   "${PNG_ICON}" --out "${ICONSET_DIR}/icon_256x256@2x.png" > /dev/null 2>&1
    sips -s format png -z 512 512   "${PNG_ICON}" --out "${ICONSET_DIR}/icon_512x512.png" > /dev/null 2>&1
    sips -s format png -z 1024 1024 "${PNG_ICON}" --out "${ICONSET_DIR}/icon_512x512@2x.png" > /dev/null 2>&1
    
    iconutil -c icns "${ICONSET_DIR}"
    cp "${PROJECT_DIR}/${APP_NAME}.icns" "${RESOURCES_DIR}/AppIcon.icns"
    
    rm -rf "${ICONSET_DIR}"
    rm -f "${PROJECT_DIR}/${APP_NAME}.icns"
    cp "${PNG_ICON}" "${RESOURCES_DIR}/MenuIcon.png"
    HAS_ICON=true
    echo "ICNS icon generated and copied. MenuIcon.png copied."
fi

if [ -f "${PROJECT_DIR}/About.md" ]; then
    cp "${PROJECT_DIR}/About.md" "${RESOURCES_DIR}/About.md"
    echo "About.md copied."
fi

echo "Creating Info.plist..."
cat <<EOF > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.macsettingcontroller.${APP_NAME}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
$(if [ "${HAS_ICON}" = true ]; then
    echo "    <key>CFBundleIconFile</key>"
    echo "    <string>AppIcon</string>"
fi)
</dict>
</plist>
EOF

echo "App bundle packaging complete! Created: ${APP_BUNDLE}"
