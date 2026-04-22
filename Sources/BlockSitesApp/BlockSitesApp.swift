import SwiftUI
import AppKit

@main
struct MonkModeApp: App {
    @StateObject private var viewModel = BlockViewModel()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
        .windowResizability(.contentSize)
    }
}
