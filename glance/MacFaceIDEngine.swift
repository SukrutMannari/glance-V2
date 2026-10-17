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

    // MARK: - Custom Face Scanner & Template Management

    private var resolvedEnrollmentPaths: (python: String, script: String) {
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
            let enrollScript = "\(dir)/enroll_face.py"
            if fm.fileExists(atPath: pythonBin) && fm.fileExists(atPath: enrollScript) {
                return (pythonBin, enrollScript)
            }
        }

        for dir in candidateDirs {
            let enrollScript = "\(dir)/enroll_face.py"
            if fm.fileExists(atPath: enrollScript) {
                for py in ["/usr/local/bin/python3", "/opt/homebrew/bin/python3", "/usr/bin/python3"] {
                    if fm.fileExists(atPath: py) {
                        return (py, enrollScript)
                    }
                }
            }
        }

        return (
            "/Users/sukrutmannari/.gemini/antigravity/scratch/MacFaceID/venv/bin/python3",
            "/Users/sukrutmannari/.gemini/antigravity/scratch/MacFaceID/enroll_face.py"
        )
    }

    func isEnrolled(username: String = NSUserName()) -> Bool {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let candidatePaths = [
            "\(home)/.macfaceid/templates/\(username).npy",
            "/Users/sukrutmannari/.gemini/antigravity/scratch/MacFaceID/templates/\(username).npy",
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("MacFaceID/templates/\(username).npy").path
        ]
        return candidatePaths.contains { fm.fileExists(atPath: $0) }
    }

    func enrolledPreviewURL(username: String = NSUserName()) -> URL? {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let candidatePaths = [
            "\(home)/.macfaceid/templates/preview_\(username).jpg",
            "/Users/sukrutmannari/.gemini/antigravity/scratch/MacFaceID/templates/preview_\(username).jpg"
        ]
        for path in candidatePaths {
            if fm.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    func enrolledDate(username: String = NSUserName()) -> Date? {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let candidatePaths = [
            "\(home)/.macfaceid/templates/\(username).npy",
            "/Users/sukrutmannari/.gemini/antigravity/scratch/MacFaceID/templates/\(username).npy"
        ]
        for path in candidatePaths {
            if let attrs = try? fm.attributesOfItem(atPath: path),
               let modDate = attrs[.modificationDate] as? Date {
                return modDate
            }
        }
        return nil
    }

    @discardableResult
    func deleteEnrollment(username: String = NSUserName()) -> Bool {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let candidatePaths = [
            "\(home)/.macfaceid/templates/\(username).npy",
            "\(home)/.macfaceid/templates/preview_\(username).jpg",
            "/Users/sukrutmannari/.gemini/antigravity/scratch/MacFaceID/templates/\(username).npy",
            "/Users/sukrutmannari/.gemini/antigravity/scratch/MacFaceID/templates/preview_\(username).jpg"
        ]
        var deletedAny = false
        for path in candidatePaths {
            if fm.fileExists(atPath: path) {
                try? fm.removeItem(atPath: path)
                deletedAny = true
            }
        }
        return deletedAny
    }

    @discardableResult
    func launchEnrollment(username: String = NSUserName(), onCompletion: (@Sendable (Bool) -> Void)? = nil) -> Process? {
        let paths = resolvedEnrollmentPaths
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: paths.python)
        proc.arguments = [paths.script, username]

        proc.terminationHandler = { process in
            let success = process.terminationStatus == 0
            DispatchQueue.main.async {
                onCompletion?(success)
            }
        }

        do {
            try proc.run()
            return proc
        } catch {
            Self.logger.error("Failed to launch enrollment: \(error.localizedDescription, privacy: .public)")
            onCompletion?(false)
            return nil
        }
    }
}
