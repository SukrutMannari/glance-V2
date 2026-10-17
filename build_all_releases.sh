#!/bin/bash
set -e

mkdir -p releases
mkdir -p dist_staging

echo "=== Preparing Universal Release ==="
rm -rf dist_staging/universal dist_staging/dmg_universal
mkdir -p dist_staging/universal
cp -R build-universal/Glance.app dist_staging/universal/
cp -R FaceScannerApp/FaceScanner.app dist_staging/universal/

mkdir -p dist_staging/dmg_universal
cp -R dist_staging/universal/* dist_staging/dmg_universal/
ln -s /Applications dist_staging/dmg_universal/Applications

echo "Packaging Universal PKG..."
pkgbuild --root dist_staging/universal --install-location /Applications --identifier com.sukrutmannari.glance --version 2.0.0 releases/Glance-v2.1-Universal.pkg

echo "Packaging Universal DMG..."
rm -f releases/Glance-v2.1-Universal.dmg
hdiutil create -volname "Glance v2.1 Universal" -srcfolder dist_staging/dmg_universal -ov -format UDZO releases/Glance-v2.1-Universal.dmg

echo "Packaging Universal ZIP..."
(cd dist_staging/universal && zip -r -q ../../releases/Glance-v2.1-Universal.zip .)

echo "=== Preparing Apple Silicon (arm64) Release ==="
rm -rf dist_staging/arm64 dist_staging/dmg_arm64
mkdir -p dist_staging/arm64
cp -R build-arm64/Build/Products/Release/glance.app dist_staging/arm64/Glance.app
cp -R FaceScannerApp/FaceScanner.app dist_staging/arm64/

mkdir -p dist_staging/dmg_arm64
cp -R dist_staging/arm64/* dist_staging/dmg_arm64/
ln -s /Applications dist_staging/dmg_arm64/Applications

echo "Packaging Apple Silicon PKG..."
pkgbuild --root dist_staging/arm64 --install-location /Applications --identifier com.sukrutmannari.glance --version 2.0.0 releases/Glance-v2.1-AppleSilicon.pkg

echo "Packaging Apple Silicon DMG..."
rm -f releases/Glance-v2.1-AppleSilicon.dmg
hdiutil create -volname "Glance v2.1 Apple Silicon" -srcfolder dist_staging/dmg_arm64 -ov -format UDZO releases/Glance-v2.1-AppleSilicon.dmg

echo "Packaging Apple Silicon ZIP..."
(cd dist_staging/arm64 && zip -r -q ../../releases/Glance-v2.1-AppleSilicon.zip .)

echo "=== Preparing Intel (x86_64) Release ==="
rm -rf dist_staging/x86_64 dist_staging/dmg_x86_64
mkdir -p dist_staging/x86_64
cp -R build/Build/Products/Release/glance.app dist_staging/x86_64/Glance.app
cp -R FaceScannerApp/FaceScanner.app dist_staging/x86_64/

mkdir -p dist_staging/dmg_x86_64
cp -R dist_staging/x86_64/* dist_staging/dmg_x86_64/
ln -s /Applications dist_staging/dmg_x86_64/Applications

echo "Packaging Intel PKG..."
pkgbuild --root dist_staging/x86_64 --install-location /Applications --identifier com.sukrutmannari.glance --version 2.0.0 releases/Glance-v2.1-Intel.pkg

echo "Packaging Intel DMG..."
rm -f releases/Glance-v2.1-Intel.dmg
hdiutil create -volname "Glance v2.1 Intel" -srcfolder dist_staging/dmg_x86_64 -ov -format UDZO releases/Glance-v2.1-Intel.dmg

echo "Packaging Intel ZIP..."
(cd dist_staging/x86_64 && zip -r -q ../../releases/Glance-v2.1-Intel.zip .)

rm -rf dist_staging
echo "=== All Releases Packaged Successfully ==="
ls -lh releases/
