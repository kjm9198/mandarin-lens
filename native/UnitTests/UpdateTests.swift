import Foundation
import Testing
@testable import MandarinLens

@Test func versionComparisonDetectsNewerReleases() {
    #expect(UpdateManager.isVersion("4.3.1", newerThan: "4.3.0"))
    #expect(UpdateManager.isVersion("4.4.0", newerThan: "4.3.0"))
    #expect(UpdateManager.isVersion("5.0.0", newerThan: "4.3.0"))
    #expect(UpdateManager.isVersion("v4.3.1", newerThan: "4.3.0"))
    #expect(UpdateManager.isVersion("v4.3.1", newerThan: "v4.3.0"))
    #expect(!UpdateManager.isVersion("4.3.0", newerThan: "4.3.0"))
    #expect(!UpdateManager.isVersion("4.2.9", newerThan: "4.3.0"))
    #expect(!UpdateManager.isVersion("4.0.0", newerThan: "4.3.0"))
    #expect(UpdateManager.isVersion("4.3.0.1", newerThan: "4.3.0"))
    #expect(!UpdateManager.isVersion("4.3.0", newerThan: "4.3.0.1"))
}

@Test func versionPayloadDecodesCorrectly() throws {
    let json = """
    {
      "latestVersion": "4.3.1",
      "releaseDate": "2026-10-31",
      "changelog": "New study modes and update improvements.",
      "macos": {
        "version": "4.3.1",
        "filename": "KamihiLens-4.3.1-macOS-arm64.dmg",
        "url": "https://lens.kamihi.workers.dev/download/macos/latest",
        "directUrl": "https://lens.kamihi.workers.dev/downloads/KamihiLens-4.3.1-macOS-arm64.dmg",
        "sha256": "abcdef1234567890",
        "minOs": "macOS 15.0"
      },
      "windows": {
        "version": "4.3.1",
        "filename": "KamihiLens-4.3.1-Windows-x64.zip",
        "url": "https://lens.kamihi.workers.dev/download/windows/latest",
        "directUrl": "https://lens.kamihi.workers.dev/downloads/KamihiLens-4.3.1-Windows-x64.zip",
        "sha256": "fedcba0987654321",
        "minOs": "Windows 10 / 11"
      }
    }
    """.data(using: .utf8)!

    let payload = try JSONDecoder().decode(LensVersionPayload.self, from: json)
    #expect(payload.latestVersion == "4.3.1")
    #expect(payload.macos?.filename == "KamihiLens-4.3.1-macOS-arm64.dmg")
    #expect(payload.macos?.sha256 == "abcdef1234567890")
    #expect(payload.windows?.filename == "KamihiLens-4.3.1-Windows-x64.zip")
    #expect(payload.changelog?.contains("New study modes") == true)
}

@Test @MainActor func updateManagerInitialState() {
    let updater = UpdateManager.shared
    #expect(!updater.currentVersion.isEmpty)
    #expect(!updater.isChecking)
    #expect(!updater.isDownloading)
}

@Test @MainActor func downloadUpdateIgnoredWhenNoUpdateAvailable() {
    let updater = UpdateManager.shared
    updater.updateAvailable = false
    updater.downloadUpdate()
    #expect(!updater.isDownloading)
}
