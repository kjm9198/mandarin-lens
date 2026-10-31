import Foundation
import AppKit
import Combine

struct LensVersionPayload: Codable {
    var latestVersion: String
    var releaseDate: String?
    var changelog: String?
    var macos: LensPlatformPayload?
    var windows: LensPlatformPayload?
}

struct LensPlatformPayload: Codable {
    var version: String
    var filename: String?
    var url: String
    var directUrl: String?
    var sha256: String?
    var minOs: String?
}

@MainActor
final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    @Published var currentVersion: String
    @Published var latestVersion: String?
    @Published var updateAvailable: Bool = false
    @Published var isChecking: Bool = false
    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var statusMessage: String = "Ready to check for updates."
    @Published var downloadedFileURL: URL? = nil
    @Published var releaseNotes: String = ""
    @Published var downloadURLString: String? = nil

    private let updateCheckEndpoint = URL(string: "https://lens.kamihi.workers.dev/api/version")!
    private let fallbackWebsiteURL = URL(string: "https://lens.kamihi.workers.dev")!

    init(bundle: Bundle = .main) {
        if let short = bundle.infoDictionary?["CFBundleShortVersionString"] as? String, !short.isEmpty {
            self.currentVersion = short
        } else {
            self.currentVersion = "4.3.0"
        }
    }

    nonisolated static func isVersion(_ remote: String, newerThan local: String) -> Bool {
        let cleanRemote = remote.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
        let cleanLocal = local.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
        let remoteParts = cleanRemote.split(separator: ".").compactMap { Int($0) }
        let localParts = cleanLocal.split(separator: ".").compactMap { Int($0) }
        let maxCount = max(remoteParts.count, localParts.count)
        for i in 0..<maxCount {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let l = i < localParts.count ? localParts[i] : 0
            if r > l { return true }
            if r < l { return false }
        }
        return false
    }

    func checkForUpdates(manual: Bool = true) async {
        guard !isChecking else { return }
        isChecking = true
        if manual { statusMessage = "Checking for latest version…" }

        do {
            var request = URLRequest(url: updateCheckEndpoint)
            request.timeoutInterval = 10
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let payload = try JSONDecoder().decode(LensVersionPayload.self, from: data)
            let remoteVer = payload.macos?.version ?? payload.latestVersion
            self.latestVersion = remoteVer
            self.releaseNotes = payload.changelog ?? ""
            self.downloadURLString = payload.macos?.directUrl ?? payload.macos?.url ?? "https://lens.kamihi.workers.dev/download/macos/latest"

            let hasNew = Self.isVersion(remoteVer, newerThan: currentVersion)
            self.updateAvailable = hasNew

            if hasNew {
                self.statusMessage = "New version \(remoteVer) is available!"
            } else {
                self.statusMessage = "You’re up to date! Kamihi Lens \(currentVersion) is the latest version."
            }
        } catch {
            if manual {
                self.statusMessage = "Check failed. You can always download the latest installer from lens.kamihi.workers.dev."
            }
        }
        isChecking = false
    }

    func downloadUpdate() {
        guard !isDownloading else { return }
        isDownloading = true
        downloadProgress = 0.05
        statusMessage = "Starting download…"

        let targetURLString = downloadURLString ?? "https://lens.kamihi.workers.dev/download/macos/latest"
        guard let url = URL(string: targetURLString) else {
            openWebsiteFallback()
            isDownloading = false
            return
        }

        Task {
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 60
                let (tempURL, response) = try await URLSession.shared.download(for: request)

                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }

                let suggestedName = response.suggestedFilename ?? "KamihiLens-latest.dmg"
                let fileManager = FileManager.default
                guard let downloadsFolder = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
                    throw URLError(.cannotCreateFile)
                }

                let destURL = downloadsFolder.appendingPathComponent(suggestedName)
                if fileManager.fileExists(atPath: destURL.path) {
                    try? fileManager.removeItem(at: destURL)
                }
                try fileManager.moveItem(at: tempURL, to: destURL)

                self.downloadedFileURL = destURL
                self.downloadProgress = 1.0
                self.statusMessage = "Downloaded \(suggestedName) to Downloads. Opening installer…"

                // Open the DMG automatically so the user doesn't have to search for it
                NSWorkspace.shared.open(destURL)
            } catch {
                // If download fails for any reason (permissions, sandbox, network), open browser download directly so it never breaks!
                self.statusMessage = "Direct download encountered an issue. Opening browser download…"
                self.openWebsiteFallback()
            }
            self.isDownloading = false
        }
    }

    func openWebsiteFallback() {
        let downloadPage = URL(string: "https://lens.kamihi.workers.dev/download/macos/latest") ?? fallbackWebsiteURL
        NSWorkspace.shared.open(downloadPage)
    }

    func openInstaller() {
        if let url = downloadedFileURL, FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.open(url)
        } else {
            openWebsiteFallback()
        }
    }
}
