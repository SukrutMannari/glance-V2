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

        var candidatePythons: [String] = [
            "\(home)/.macfaceid/venv/bin/python3",
            "/Users/sukrutmannari/.gemini/antigravity/scratch/MacFaceID/venv/bin/python3"
        ]
        if let res = Bundle.main.resourceURL {
            candidatePythons.append(res.appendingPathComponent("MacFaceID/venv/bin/python3").path)
        }
        candidatePythons.append("/usr/local/bin/python3")
        candidatePythons.append("/opt/homebrew/bin/python3")

        var pythonBin: String?
        for py in candidatePythons {
            if fm.fileExists(atPath: py) {
                pythonBin = py
                break
            }
        }

        var candidateScripts: [String] = [
            "\(home)/.macfaceid/enroll_face.py",
            "/Applications/Glance.app/Contents/Resources/MacFaceID/enroll_face.py",
            "/Users/sukrutmannari/.gemini/antigravity/scratch/MacFaceID/enroll_face.py"
        ]
        if let res = Bundle.main.resourceURL {
            candidateScripts.append(res.appendingPathComponent("MacFaceID/enroll_face.py").path)
        }

        var scriptPath: String?
        for sc in candidateScripts {
            if fm.fileExists(atPath: sc) {
                scriptPath = sc
                break
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
