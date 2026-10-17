<h1 align="center">
  <br>
  <img src="glance/Assets.xcassets/appicon.imageset/appicon.png" alt="Glance-V2" width="140">
  <br>
  Glance-V2
  <br>
</h1>

<h3 align="center">Next-Generation Biometric Face ID Unlock for macOS (Apple Silicon & Intel)</h3>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-black.svg" alt="MIT License"></a>
  <img src="https://img.shields.io/badge/macOS-14%20%7C%2015%2B-black.svg" alt="macOS 14/15+">
  <img src="https://img.shields.io/badge/Architecture-Apple%20Silicon%20(arm64)%20%7C%20Intel%20(x86__64)-blue.svg" alt="Architecture">
  <img src="https://img.shields.io/badge/Engine-OpenCV%20YuNet%20%2B%20SFace-green.svg" alt="OpenCV Biometrics">
  <img src="https://img.shields.io/badge/Swift-SwiftUI-orange.svg" alt="Swift">
</p>

Glance-V2 brings seamless **Face ID unlock** to your Mac with an ultra-fast, local biometrics pipeline. Unlock your Mac automatically on wake, on lock, or on pressing Space at the lock screen — no typing required!

Everything runs **100% offline and locally** on your machine. Your face embeddings and credentials never leave your Mac.

---

> [!NOTE]
> ### 🌟 Attribution & Credit to Original Developer
> **Glance-V2** is a supercharged fork and engine overhaul based on the outstanding work of **Jonathan Zhou ([@jonnyoo](https://github.com/jonnyoo))** on [Glance](https://github.com/jonnyoo/glance).
> 
> Full credit goes to Jonathan Zhou for the original SwiftUI architecture, dynamic island notch animations, and core vision pipeline. Glance-V2 enhances this foundation with an OpenCV-powered YuNet & SFace biometrics engine, multi-sample interactive enrollment, low-light backlight compensation, and support for Macs without Touch ID hardware (including Hackintoshes).

---

## ⚡ What's New in Glance-V2

- 🧠 **OpenCV YuNet + SFace Engine**: Replaced legacy ArcFace model with YuNet (ultra-fast 320x320 face detector) and SFace (deep 128-dimensional cosine feature extractor). Recognizes faces in **~0.6s** with over 99% accuracy.
- 💻 **Native Apple Silicon & Intel Builds**: Standalone compiled binaries tailored for **Apple M-series chips (`arm64`)** and **Intel Macs (`x86_64`)**.
- 🛠️ **Universal Compatibility (No Touch ID Required)**: Re-architected credential management so Macs without hardware Touch ID / Secure Enclaves (like Hackintoshes, Mac mini, Mac Studio, or older MacBooks) can use full Face ID unlock without errors.
- 💡 **Low-Light / Backlight Gamma Boost**: Integrated dynamic gamma lookup table (LUT) processing to detect and match faces even in dimly lit rooms or against screen backlights.
- 🎯 **Multi-Sample Interactive Enrollment GUI**: Built-in Cocoa preview window with facial landmark tracking, progress rings, audio chimes, and automatic multi-angle vector averaging.
- ⌨️ **Bulletproof Lock Screen Injection**: Calibrated keystroke injection timing (batch delay + pre-return settle) to ensure macOS `loginwindow`'s `NSSecureTextField` never drops characters.
- 🔍 **Dynamic Path Discovery**: The engine automatically detects dependencies from `~/.macfaceid`, the Application Bundle, or local virtual environments.

---

## 📥 Downloads & Installation

Pre-compiled app bundles are available in [GitHub Releases](https://github.com/SukrutMannari/glance-V2/releases):

- **Apple Silicon (M1/M2/M3/M4 Macs)**: `Glance-AppleSilicon.zip`
- **Intel Macs (or Hackintoshes)**: `Glance-Intel.zip`

1. Download the archive for your Mac architecture.
2. Unzip and drag `Glance.app` to your `/Applications` folder.
3. Open `Glance.app` from `/Applications`.

---

## 🚀 Setting Up the Biometrics Engine

Glance-V2 utilizes a lightweight, local OpenCV Python biometrics engine (`MacFaceID`). You only need to set it up once:

### 1. Run Automated Setup

Open Terminal and run:

```bash
cd /Applications/Glance.app/Contents/Resources/MacFaceID 2>/dev/null || cd MacFaceID
chmod +x install.sh
./install.sh
```

*Or manually in any directory:*
```bash
python3 -m venv ~/.macfaceid/venv
~/.macfaceid/venv/bin/pip install opencv-python numpy
python3 MacFaceID/download_models.py
```

---

## 👤 Enrolling Your Face

To enroll your face into Glance-V2's biometric database:

```bash
# From the MacFaceID directory:
./venv/bin/python3 enroll_face.py
```
*(Or use `~/.macfaceid/venv/bin/python3 MacFaceID/enroll_face.py`)*

### Enrollment Tips:
1. A live camera preview window will pop up on your screen.
2. Center your face inside the green bounding box and look directly at your webcam.
3. Tilt your head slightly up/down/left/right as prompted by the audio chimes.
4. Once 5 high-resolution feature vectors are recorded, you'll hear a confirmation chime and your template is saved!

---

## 🔒 Permissions & Configuration

Glance requires the following standard macOS permissions:

| Permission | Purpose |
|---|---|
| **Camera** | Used by OpenCV to capture frames in memory during unlock scans. Frames are never saved to disk. |
| **Accessibility** | Required to type your saved password into the macOS lock screen upon biometric verification. |

### Granting Accessibility:
1. Open **System Settings** → **Privacy & Security** → **Accessibility**.
2. Ensure **Glance** is enabled.
3. If macOS prompts after an update, reset permissions via Terminal:
   ```bash
   tccutil reset Accessibility com.jonathan.glance
   ```

---

## ⚙️ Features & Settings

- **Auto-Unlock Triggers**:
  - **On Wake**: Scans automatically as soon as your display wakes up.
  - **On Lock**: Instantly begins scanning when you lock your Mac.
  - **On Space Key**: Press the Space bar on the lock screen to trigger an immediate face scan.
- **Dock & Menu Bar Options**: Hide Glance from your Dock so it runs quietly in your Menu Bar.
- **Adjustable Timeout & Strictness**: Set scan duration (5s to 15s) and cosine similarity thresholds.

---

## 🛠️ Building from Source

### Prerequisites
- macOS 14.0 Sonoma or macOS 15.0 Sequoia+
- Xcode 15 or 16+

### Build Steps

```bash
# Clone the repository
git clone https://github.com/SukrutMannari/glance-V2.git
cd glance-V2

# Build for your current architecture
xcodebuild -project glance.xcodeproj -scheme glance -configuration Release build
```

To build specifically for Apple Silicon or Intel:
```bash
# Apple Silicon (M-series)
xcodebuild -project glance.xcodeproj -scheme glance -configuration Release ARCHS="arm64" ONLY_ACTIVE_ARCH=NO -derivedDataPath ./build-arm64 build

# Intel (x86_64)
xcodebuild -project glance.xcodeproj -scheme glance -configuration Release ARCHS="x86_64" ONLY_ACTIVE_ARCH=NO -derivedDataPath ./build build
```

---

## 📜 Credits & Acknowledgements

- **Jonathan Zhou ([@jonnyoo](https://github.com/jonnyoo))** — Creator of the original [Glance](https://github.com/jonnyoo/glance) application, notch physics, and SwiftUI UI.
- **[OpenCV Zoo](https://github.com/opencv/opencv_zoo)** — YuNet Face Detector and SFace Face Recognizer ONNX models.
- **[The Boring Notch](https://github.com/TheBoredTeam/boring.notch)** — Notch window physics.
- **Sukrut Mannari ([@SukrutMannari](https://github.com/SukrutMannari))** — Glance-V2 engine overhaul, Hackintosh & Touch ID-less credential architecture, multi-sample enrollment GUI, low-light boost, and multi-architecture builds.

---

## ⚖️ License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for details.
