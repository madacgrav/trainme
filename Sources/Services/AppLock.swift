import Foundation
import LocalAuthentication
import Observation

@MainActor
@Observable
final class AppLock {
    var isUnlocked = false

    /// Face ID / Touch ID with automatic device-passcode fallback. Devices with
    /// no passcode configured are treated as unlocked (nothing to auth against).
    func authenticate() async {
        // A fresh LAContext per attempt: reused contexts skip the prompt.
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            isUnlocked = true
            return
        }
        isUnlocked = (try? await context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Unlock TrainMe"
        )) ?? false
    }

    func lock() {
        isUnlocked = false
    }
}
