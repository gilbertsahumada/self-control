import SwiftUI

/// Fake terminal boot sequence shown on launch. Purely cosmetic — the real
/// init work happens in `BlockViewModel.init`, which is near-instant. Each
/// line appears after a short stagger so the screen reads like a POST on a
/// CRT: kernel messages streaming in with a blinking cursor at the bottom.
struct BootSequenceView: View {
    let onFinished: () -> Void

    private static let messages: [(stamp: String, text: String)] = [
        ("0.0000", "monkmode boot sequence"),
        ("0.0142", "initializing phosphor display driver"),
        ("0.0318", "mounting /etc/hosts ro"),
        ("0.0487", "loading DoH blocklist (8 providers)"),
        ("0.0651", "verifying enforcer daemon signature"),
        ("0.0803", "probing pf anchor com.monkmode"),
        ("0.0967", "scanning for stale markers"),
        ("0.1124", "checking config.json"),
        ("0.1289", "seeding adversarial corpus"),
        ("0.1450", "warming up LaunchDaemon shim"),
        ("0.1612", "engaging distraction suppressor"),
        ("0.1784", "ready"),
    ]

    @State private var visibleCount = 0
    @State private var startedExit = false

    private let lineDelay: TimeInterval = 0.09
    private let trailingPause: TimeInterval = 0.4

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 4) {
                Text("[ MONKMODE ] cold boot // ttyS0")
                    .font(Theme.monoSM.weight(.bold))
                    .foregroundColor(Theme.phosphor)
                    .padding(.bottom, 8)

                ForEach(0..<visibleCount, id: \.self) { idx in
                    line(at: idx)
                }

                if visibleCount >= Self.messages.count {
                    HStack(spacing: 6) {
                        Text("$")
                            .foregroundColor(Theme.phosphorDim)
                        Text("_")
                            .foregroundColor(Theme.phosphor)
                    }
                    .font(Theme.monoSM)
                    .padding(.top, 8)
                }

                Spacer()
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .topLeading)

            Scanlines().ignoresSafeArea()
            CRTFlicker().ignoresSafeArea()
        }
        .transition(.opacity)
        .onAppear { scheduleNext() }
    }

    private func line(at idx: Int) -> some View {
        let entry = Self.messages[idx]
        let isReady = idx == Self.messages.count - 1
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("[ \(entry.stamp) ]")
                .foregroundColor(Theme.phosphorMuted)
            Text(entry.text)
                .foregroundColor(isReady ? Theme.phosphor : Theme.foreground)
            if isReady {
                Text("OK")
                    .foregroundColor(Theme.phosphor)
                    .bold()
            }
            Spacer(minLength: 0)
        }
        .font(Theme.monoSM)
        .lineLimit(1)
    }

    private func scheduleNext() {
        guard !startedExit else { return }
        if visibleCount < Self.messages.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + lineDelay) {
                withAnimation(.linear(duration: 0.08)) {
                    visibleCount += 1
                }
                scheduleNext()
            }
        } else {
            startedExit = true
            DispatchQueue.main.asyncAfter(deadline: .now() + trailingPause) {
                onFinished()
            }
        }
    }
}
