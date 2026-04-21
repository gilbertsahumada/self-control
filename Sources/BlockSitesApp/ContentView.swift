import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: BlockViewModel

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            Group {
                if viewModel.isBlocking {
                    ActiveBlockView()
                } else {
                    SetupView()
                }
            }
        }
        .frame(minWidth: 520, minHeight: 600)
        .preferredColorScheme(.dark)
    }
}
