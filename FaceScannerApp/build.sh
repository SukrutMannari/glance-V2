#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "Building FaceScanner universal binary..."
swiftc -O -target arm64-apple-macos14.0 main.swift -o FaceScanner_arm64
swiftc -O -target x86_64-apple-macos14.0 main.swift -o FaceScanner_x86
lipo -create -output FaceScanner FaceScanner_arm64 FaceScanner_x86

mkdir -p FaceScanner.app/Contents/MacOS
mkdir -p FaceScanner.app/Contents/Resources
cp FaceScanner FaceScanner.app/Contents/MacOS/
cp Info.plist FaceScanner.app/Contents/
cp AppIcon.icns FaceScanner.app/Contents/Resources/
echo -n "APPL????" > FaceScanner.app/Contents/PkgInfo
cp -R ../MacFaceID FaceScanner.app/Contents/Resources/

echo "FaceScanner.app built successfully!"
