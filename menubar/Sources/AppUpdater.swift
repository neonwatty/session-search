import Foundation
import Sparkle

@MainActor
final class AppUpdater: ObservableObject {
    static let shared = AppUpdater()

    let isConfigured: Bool
    private let updaterController: SPUStandardUpdaterController?

    private init() {
        let bundle = Bundle.main
        let publicKey = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        let feedURL = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
        isConfigured =
            !publicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !publicKey.contains("$(")
            && URL(string: feedURL) != nil

        if isConfigured {
            updaterController = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        } else {
            updaterController = nil
        }
    }

    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }
}
