import Foundation
import Sparkle

@MainActor
public final class SparkleUpdater: NSObject, ObservableObject {
    public static let shared = SparkleUpdater()
    
    public let updaterController: SPUStandardUpdaterController
    @Published public var canCheckForUpdates: Bool = false
    
    private override init() {
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
        
        self.updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
    
    public func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
