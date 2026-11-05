import SwiftUI

/// The lock (Batch J): the app-switcher cover's look — aura, mark, a greeting — with the
/// unlock button once it's locked. While it's only covering, it reads exactly like §4.3.
struct LockScreenView: View {
    let lock: AppLock
    @AppStorage(PrivacyCoverLines.key) private var lineIndex = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AuraBackground(isFrozen: true)
            VStack(spacing: Spacing.l) {
                // Covering, it reads exactly like §4.3 (centred). Locked, the mark and greeting
                // sit above the system's Face ID panel, which appears in the middle.
                if lock.state == .locked { Spacer().frame(maxHeight: 140) } else { Spacer() }
                AppMark()
                Text(lock.state == .locked ? greeting : PrivacyCoverLines.line(lineIndex, name: lock.displayName))
                    .folioFont(.title2)
                    .foregroundStyle(.inkSecondary)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                Spacer()
                if lock.state == .locked {
                    VStack(spacing: Spacing.s) {
                        if let problem = lock.problem {
                            Text(problem).folioFont(.callout).foregroundStyle(.danger)
                        }
                        Button {
                            Task { await lock.unlock() }
                        } label: {
                            Label("Unlock with \(lock.methodName)", systemImage: lock.methodSymbol)
                                .font(.headline)
                                .padding(.horizontal, Spacing.m)
                                .frame(minHeight: Spacing.minHitTarget)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.emberStrong)
                        .disabled(lock.isAuthenticating)
                        .accessibilityIdentifier("lock.unlock")
                    }
                    .padding(.bottom, 72)
                    .transition(.opacity.combined(with: .scale(scale: reduceMotion ? 1 : 0.96)))
                }
            }
            .padding(.horizontal, Spacing.sideMargin)
            .animation(reduceMotion ? FolioMotion.reduced : FolioMotion.standard(), value: lock.state)
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: AppClock.now)
        let name = lock.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return Greetings.pool(for: GreetingPeriod(hour: hour)).first?.text(name: name.isEmpty ? nil : name) ?? ""
    }
}
