import SwiftUI

/// Gates the app behind biometric auth. Locks on `.background` only — Face ID's
/// own system UI briefly drops the app to `.inactive`, which must NOT re-lock.
struct LockGateView<Content: View>: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var lock = AppLock()
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            if lock.isUnlocked {
                content()
            } else {
                lockScreen
            }
        }
        .task { await lock.authenticate() }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                lock.lock()
            case .active:
                if !lock.isUnlocked {
                    Task { await lock.authenticate() }
                }
            default:
                break
            }
        }
    }

    private var lockScreen: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("TrainMe is locked")
                .font(.headline)
            Button("Unlock") {
                Task { await lock.authenticate() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}
