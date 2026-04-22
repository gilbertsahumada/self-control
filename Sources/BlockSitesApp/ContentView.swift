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

            Scanlines()
                .ignoresSafeArea()
            CRTFlicker()
                .ignoresSafeArea()
        }
        .frame(minWidth: 560, minHeight: 640)
        .preferredColorScheme(.dark)
    }
}
