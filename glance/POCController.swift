//
//  POCController.swift
//  glance
//
//  Orchestration for credential storage: wires SecureCredentialManager to
//  KeystrokeInjector and exposes session/password status for Settings.
//

import Foundation
import Observation

@Observable
@MainActor
final class POCController {
    var accessibilityGranted: Bool = KeystrokeInjector.isAccessibilityTrusted()

    var hasStoredPassword: Bool = SecureCredentialManager.hasStoredPassword()
    var isSessionUnlocked: Bool = SecureCredentialManager.isSessionUnlocked
    var sessionError: String? = nil

    /// Bound to the setup SecureField. Cleared immediately after a successful save.
    var passwordInput: String = ""

    var statusMessage: String = "Idle"

    func refreshAccessibilityStatus() {
        accessibilityGranted = KeystrokeInjector.isAccessibilityTrusted()
    }

    func requestAccessibility() {
        KeystrokeInjector.promptForAccessibility()
    }

    func refreshCredentialStatus() {
        hasStoredPassword = SecureCredentialManager.hasStoredPassword()
        isSessionUnlocked = SecureCredentialManager.isSessionUnlocked
    }

    // MARK: - Session (Touch ID gate)

    /// Must succeed before `savePassword()` or `injectStoredPassword()` will do anything.
    func unlockSession() async {
        sessionError = nil
        do {
            try await Task.detached(priority: .userInitiated) {
                try SecureCredentialManager.unlockSession(reason: "Authenticate to set up or use glance")
            }.value
            isSessionUnlocked = true
        } catch {
            isSessionUnlocked = false
            sessionError = error.localizedDescription
        }
    }

    func lockSession() {
        SecureCredentialManager.lockSession()
        isSessionUnlocked = false
    }

    // MARK: - Setup flow

    /// Encrypts and stores `passwordInput`. Requires the session to already
    /// be unlocked (Touch ID happens in `unlockSession()`, not here).
    func savePassword() async {
        guard !passwordInput.isEmpty else {
            statusMessage = "Enter a password first."
            return
        }
        let plaintext = passwordInput
        passwordInput = ""

        do {
            try await Task.detached(priority: .userInitiated) {
                guard var bytes = plaintext.data(using: .utf8) else {
                    throw SecureCredentialError.emptyPassword
                }
                defer { bytes.resetBytes(in: 0..<bytes.count) }
                try SecureCredentialManager.savePassword(bytes)
            }.value
            statusMessage = "Password saved and encrypted."
            hasStoredPassword = true
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Injection

    private nonisolated func logUnlock(_ message: String) {
        let line = "[\(Date())] \(message)\n"
        if let data = line.data(using: .utf8) {
            let url = URL(fileURLWithPath: "/tmp/glance_unlock.log")
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: url)
            }
        }
    }

    /// Reads + decrypts + injects the stored password, zeroing the plaintext
    /// buffer before returning. When `requireAuthoritativeLock` is true (the
    /// auto-trigger path), refuses to inject unless the CGSession dictionary
    /// confirms the screen is actually locked.
    func injectStoredPassword(requireAuthoritativeLock: Bool = false) async {
        logUnlock("injectStoredPassword called (requireAuthoritativeLock: \(requireAuthoritativeLock))")
        let axTrusted = KeystrokeInjector.isAccessibilityTrusted()
        let sessionUnlocked = SecureCredentialManager.isSessionUnlocked
        let hasPassword = SecureCredentialManager.hasStoredPassword()
        let isLocked = LockMonitor.isScreenActuallyLocked()
        
        logUnlock("State: axTrusted=\(axTrusted), sessionUnlocked=\(sessionUnlocked), hasPassword=\(hasPassword), isLocked=\(isLocked)")

        guard axTrusted else {
            statusMessage = "Accessibility not granted — open System Settings and enable glance."
            logUnlock("FAILED: Accessibility not granted (isAccessibilityTrusted == false) — triggering system prompt")
            DispatchQueue.main.async {
                KeystrokeInjector.promptForAccessibility()
            }
            return
        }
        guard sessionUnlocked else {
            statusMessage = "Session locked — authenticate with Touch ID first."
            logUnlock("FAILED: Session is locked (isSessionUnlocked == false)")
            return
        }

        if requireAuthoritativeLock {
            guard isLocked else {
                statusMessage = "Skipped: CGSession reports screen is not actually locked."
                logUnlock("SKIPPED: CGSession reports screen is not actually locked")
                return
            }
        }

        statusMessage = "Injecting…"
        logUnlock("Reading password from SecureCredentialManager...")
        do {
            try await Task.detached(priority: .userInitiated) {
                var bytes = try SecureCredentialManager.readPassword()
                self.logUnlock("Read password successfully, count = \(bytes.count) bytes. Calling KeystrokeInjector.typeAndReturn...")
                defer { bytes.resetBytes(in: 0..<bytes.count) }
                try KeystrokeInjector.typeAndReturn(bytes)
                self.logUnlock("KeystrokeInjector.typeAndReturn finished successfully.")
            }.value
            statusMessage = "Injected stored password + Return at \(Date().formatted(date: .omitted, time: .standard))"
            logUnlock("SUCCESS: Password injected and return pressed.")
        } catch {
            statusMessage = "Injection failed: \(error.localizedDescription)"
            logUnlock("FAILED: Injection error: \(error.localizedDescription)")
        }
    }
}
