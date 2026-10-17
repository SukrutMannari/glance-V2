//
//  main.swift
//  FaceScanner
//
//  Standalone Face Scanner App for Glance-V2 (OpenCV YuNet + SFace engine).
//

import AppKit
import Foundation

final class FaceScannerApp: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path

        let candidateDirs = [
            Bundle.main.resourceURL?.appendingPathComponent("MacFaceID").path,
            "\(home)/.macfaceid",
            "/Applications/Glance.app/Contents/Resources/MacFaceID",
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("MacFaceID").path,
            "/Users/sukrutmannari/.gemini/antigravity/scratch/MacFaceID"
        ].compactMap { $0 }

        var pythonBin: String?
        var scriptPath: String?

        for dir in candidateDirs {
            let py = "\(dir)/venv/bin/python3"
            let sc = "\(dir)/enroll_face.py"
            if fm.fileExists(atPath: py) && fm.fileExists(atPath: sc) {
                pythonBin = py
                scriptPath = sc
                break
            }
        }

        if pythonBin == nil || scriptPath == nil {
            for dir in candidateDirs {
                let sc = "\(dir)/enroll_face.py"
                if fm.fileExists(atPath: sc) {
                    for sysPy in ["/usr/local/bin/python3", "/opt/homebrew/bin/python3", "/usr/bin/python3"] {
                        if fm.fileExists(atPath: sysPy) {
                            pythonBin = sysPy
                            scriptPath = sc
                            break
                        }
                    }
                    if pythonBin != nil { break }
                }
            }
        }

        guard let pyBin = pythonBin, let script = scriptPath else {
            let alert = NSAlert()
            alert.messageText = "Face Scanner Setup Required"
            alert.informativeText = "MacFaceID engine files or Python environment were not found. Please ensure Glance-V2 is installed."
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
            NSApp.terminate(nil)
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pyBin)
        process.arguments = [script, NSUserName()]

        process.terminationHandler = { proc in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }

        do {
            try process.run()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Error Launching Face Scanner"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
            NSApp.terminate(nil)
        }
    }
}

let app = NSApplication.shared
let delegate = FaceScannerApp()
app.delegate = delegate
app.run()
