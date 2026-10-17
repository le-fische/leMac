import SwiftUI
import Sparkle
import Combine

@MainActor
public final class SoftwareUpdater: ObservableObject {
    public static let shared = SoftwareUpdater()

    public let updaterController: SPUStandardUpdaterController
    @Published public var canCheckForUpdates: Bool = false

    private init() {
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.updaterController = controller

        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    public func checkForUpdates() {
        updaterController.updater.checkForUpdates()
    }

    public var automaticallyChecksForUpdates: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set {
            updaterController.updater.automaticallyChecksForUpdates = newValue
            objectWillChange.send()
        }
    }

    public var automaticallyDownloadsUpdates: Bool {
        get { updaterController.updater.automaticallyDownloadsUpdates }
        set {
            updaterController.updater.automaticallyDownloadsUpdates = newValue
            objectWillChange.send()
        }
    }
}
