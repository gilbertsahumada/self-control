import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: BlockViewModel

    var body: some View {
        Group {
            if viewModel.isBlocking {
                ActiveBlockView()
            } else {
                SetupView()
            }
        }
        .frame(minWidth: 440, minHeight: 520)
    }
}
