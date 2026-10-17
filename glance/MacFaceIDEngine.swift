//
//  MacFaceIDEngine.swift
//  glance
//
//  Bridges Glance's lock-screen coordinator to our OpenCV YuNet + SFace engine.
//

import Foundation
import os

enum MacFaceIDResult {
    case matched
    case noMatch
    case error(String)
}

final class MacFaceIDEngine: @unchecked Sendable {
    static let shared = MacFaceIDEngine()
    private static let logger = Logger(subsystem: "com.jonathan.glance", category: "MacFaceIDEngine")

    private var resolvedPaths: (python: String, script: String) {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path

        var candidateDirs: [String] = []
        if let res = Bundle.main.resourceURL?.appendingPathComponent("MacFaceID").path {
            candidateDirs.append(res)
        }
        candidateDirs.append("\(home)/.macfaceid")
        candidateDirs.append(Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("MacFaceID").path)
        candidateDirs.append("/Users/sukrutmannari/.gemini/antigravity/scratch/MacFaceID")

        for dir in candidateDirs {
            let pythonBin = "\(dir)/venv/bin/python3"
            let verifyScript = "\(dir)/verify_face.py"
            if fm.fileExists(atPath: pythonBin) && fm.fileExists(atPath: verifyScript) {
                return (pythonBin, verifyScript)
            }
        }

        for dir in candidateDirs {
            let verifyScript = "\(dir)/verify_face.py"
            if fm.fileExists(atPath: verifyScript) {
                for py in ["/usr/local/bin/python3", "/opt/homebrew/bin/python3", "/usr/bin/python3"] {
                    if fm.fileExists(atPath: py) {
                        return (py, verifyScript)
                    }
                }
            }
        }

        // Default fallback
        return (
            "/Users/sukrutmannari/.gemini/antigravity/scratch/MacFaceID/venv/bin/python3",
            "/Users/sukrutmannari/.gemini/antigravity/scratch/MacFaceID/verify_face.py"
        )
    }

    private var activeProcess: Process?
    private let lock = NSLock()

    func cancel() {
        lock.lock()
        defer { lock.unlock() }
        if let proc = activeProcess, proc.isRunning {
            Self.logger.info("Cancelling active face verification process")
            proc.terminate()
        }
        activeProcess = nil
    }

    func verify(username: String = NSUserName(), timeoutSeconds: Double = 6.0) async -> MacFaceIDResult {
        cancel()

        let paths = resolvedPaths
        let process = Process()
        process.executableURL = URL(fileURLWithPath: paths.python)
        process.arguments = [paths.script, username, String(format: "%.1f", timeoutSeconds)]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        lock.lock()
        activeProcess = process
        lock.unlock()

        Self.logger.info("Starting MacFaceID verification for \(username, privacy: .public), timeout=\(timeoutSeconds, privacy: .public)s")

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try process.run()
                        process.waitUntilExit()

                        self.lock.lock()
                        self.activeProcess = nil
                        self.lock.unlock()

                        let status = process.terminationStatus
                        Self.logger.info("MacFaceID process terminated with status \(status, privacy: .public)")

                        if status == 0 {
                            continuation.resume(returning: .matched)
                        } else if status == 1 {
                            continuation.resume(returning: .noMatch)
                        } else {
                            let data = pipe.fileHandleForReading.readDataToEndOfFile()
                            let output = String(data: data, encoding: .utf8) ?? "Verification error"
                            continuation.resume(returning: .error(output))
                        }
                    } catch {
                        self.lock.lock()
                        self.activeProcess = nil
                        self.lock.unlock()
                        Self.logger.error("Failed to run MacFaceID process: \(error.localizedDescription, privacy: .public)")
                        continuation.resume(returning: .error(error.localizedDescription))
                    }
                }
            }
        } onCancel: {
            process.terminate()
        }
    }
}
