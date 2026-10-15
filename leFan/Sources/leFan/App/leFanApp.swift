import SwiftUI

@main
struct leFanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            MainWindowView(appState: appState)
                .background(.ultraThinMaterial)
        }
        .windowToolbarStyle(.unified)
        .windowResizability(.contentSize)
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .appInfo) {
                Button("About leFan") {
                    appDelegate.openMainWindow()
                }
            }
        }
    }
}
