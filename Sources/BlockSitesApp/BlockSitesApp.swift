import SwiftUI

@main
struct BlockSitesApp: App {
    @StateObject private var viewModel = BlockViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
        .windowResizability(.contentSize)
    }
}
