import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: BlockViewModel
    @State private var booted = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if booted {
                mainUI
                    .transition(.opacity)
            } else {
                BootSequenceView {
                    withAnimation(.easeOut(duration: 0.35)) {
                        booted = true
                    }
                }
                .transition(.opacity)
            }
        }
        .frame(minWidth: 560, minHeight: 640)
        .preferredColorScheme(.dark)
    }

    private var mainUI: some View {
        ZStack {
            Group {
                if viewModel.isBlocking {
                    ActiveBlockView()
                } else {
                    SetupView()
                }
            }

            Scanlines().ignoresSafeArea()
            CRTFlicker().ignoresSafeArea()
        }
    }
}
