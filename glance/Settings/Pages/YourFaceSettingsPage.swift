//
//  YourFaceSettingsPage.swift
//  glance
//
//  Glance-V2 Face Biometrics Page.
//  Integrated with the OpenCV YuNet + SFace engine and custom interactive face scanner.
//

import SwiftUI
import AppKit

struct YourFaceSettingsPage: View {
    let environment: AppEnvironment

    @State private var isEnrolled = MacFaceIDEngine.shared.isEnrolled()
    @State private var isScanning = false
    @State private var isTesting = false
    @State private var testResult: String?
    @State private var showDeleteAlert = false

    private let username = NSUserName()

    private var enrolledDateFormatted: String {
        guard let date = MacFaceIDEngine.shared.enrolledDate() else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsMetrics.rowSpacing) {
            engineInfoCard

            if isEnrolled {
                enrolledCard
            } else {
                notEnrolledCard
            }

            if let testResult {
                testResultCard(testResult)
            }
        }
        .onAppear {
            refreshEnrollment()
        }
        .confirmationDialog(
            "Delete enrolled face?",
            isPresented: $showDeleteAlert,
            titleVisibility: .visible
        ) {
            Button("Delete Face", role: .destructive) {
                MacFaceIDEngine.shared.deleteEnrollment()
                refreshEnrollment()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove your facial template from Glance-V2. You will need to scan your face again to use Face ID.")
        }
    }

    // MARK: - Engine Info Card

    private var engineInfoCard: some View {
        SettingsGroup {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "cpu")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.accentColor)

                    Text("Glance-V2 Biometrics Engine")
                        .font(SettingsMetrics.rowFont)
                        .foregroundStyle(SettingsMetrics.textPrimary)

                    Spacer(minLength: 8)

                    Text("100% Offline")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                }

                Text("Powered by OpenCV YuNet (Ultra-fast 320x320 face detector) and SFace (128-dimensional deep feature extractor). All face data is encrypted and processed strictly in memory on your Mac.")
                    .font(.system(size: 12))
                    .foregroundStyle(SettingsMetrics.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, SettingsMetrics.rowHorizontalInset)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Enrolled State Card

    private var enrolledCard: some View {
        SettingsGroup {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    // Face preview photo or avatar
                    if let url = MacFaceIDEngine.shared.enrolledPreviewURL(),
                       let nsImage = NSImage(contentsOf: url) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 52, height: 52)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.green, lineWidth: 2))
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.15))
                                .frame(width: 52, height: 52)
                            Image(systemName: "faceid")
                                .font(.system(size: 26))
                                .foregroundStyle(.green)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(username)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(SettingsMetrics.textPrimary)

                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.green)
                        }

                        Text("Enrolled: \(enrolledDateFormatted)")
                            .font(.system(size: 12))
                            .foregroundStyle(SettingsMetrics.textTertiary)

                        Text("Template: 5 Feature Vectors (YuNet + SFace)")
                            .font(.system(size: 11))
                            .foregroundStyle(SettingsMetrics.textTertiary)
                    }

                    Spacer()

                    Button {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundStyle(.red.opacity(0.8))
                            .frame(width: 30, height: 30)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Delete Face")
                }

                Divider()
                    .padding(.vertical, 2)

                // Actions row
                HStack(spacing: 10) {
                    Button {
                        launchScanner()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isScanning ? "hourglass" : "camera.fill")
                                .font(.system(size: 12))
                            Text(isScanning ? "Scanner Active…" : "Re-scan Face")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(SettingsMetrics.neutralButtonFill)
                        .overlay(
                            Capsule().strokeBorder(SettingsMetrics.rowBorder, lineWidth: SettingsMetrics.rowBorderWidth)
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isScanning)

                    Button {
                        runTestScan()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isTesting ? "arrow.triangle.2.circlepath" : "faceid")
                                .font(.system(size: 12))
                            Text(isTesting ? "Testing…" : "Test Face Recognition")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(SettingsMetrics.neutralButtonFill)
                        .overlay(
                            Capsule().strokeBorder(SettingsMetrics.rowBorder, lineWidth: SettingsMetrics.rowBorderWidth)
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isTesting || isScanning)

                    Spacer()
                }
            }
            .padding(.horizontal, SettingsMetrics.rowHorizontalInset)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Not Enrolled State Card

    private var notEnrolledCard: some View {
        SettingsGroup {
            VStack(spacing: 16) {
                Image(systemName: "faceid")
                    .font(.system(size: 42))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 8)

                VStack(spacing: 4) {
                    Text("Face ID Not Enrolled")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(SettingsMetrics.textPrimary)

                    Text("Scan your face with our custom live camera scanner. Captures 5 high-resolution multi-angle feature vectors for reliable unlocking.")
                        .font(.system(size: 12))
                        .foregroundStyle(SettingsMetrics.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Button {
                    launchScanner()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isScanning ? "hourglass" : "camera.viewfinder")
                            .font(.system(size: 14, weight: .semibold))
                        Text(isScanning ? "Scanner Window Open…" : "Launch Custom Face Scanner")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isScanning)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, SettingsMetrics.rowHorizontalInset)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Test Result Card

    private func testResultCard(_ result: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: result.contains("Verified") ? "checkmark.circle.fill" : (result.contains("Testing") ? "hourglass" : "xmark.circle.fill"))
                .foregroundStyle(result.contains("Verified") ? .green : (result.contains("Testing") ? .orange : .red))

            Text(result)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SettingsMetrics.textPrimary)

            Spacer()

            Button("Dismiss") {
                testResult = nil
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundStyle(SettingsMetrics.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(SettingsMetrics.neutralButtonFill)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Actions

    private func refreshEnrollment() {
        isEnrolled = MacFaceIDEngine.shared.isEnrolled()
    }

    private func launchScanner() {
        isScanning = true
        testResult = nil
        MacFaceIDEngine.shared.launchEnrollment { success in
            isScanning = false
            refreshEnrollment()
            if success {
                testResult = "✅ Face successfully enrolled and saved!"
            }
        }
    }

    private func runTestScan() {
        isTesting = true
        testResult = "Scanning your face (look at camera)…"
        Task {
            let result = await MacFaceIDEngine.shared.verify(timeoutSeconds: 5.0)
            await MainActor.run {
                isTesting = false
                switch result {
                case .matched:
                    testResult = "✅ Face Verified! Match score accepted."
                case .noMatch:
                    testResult = "❌ No Match. Face did not match enrolled template."
                case .error(let msg):
                    testResult = "⚠️ Scan Error: \(msg)"
                }
            }
        }
    }
}
