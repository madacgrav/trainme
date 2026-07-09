import Foundation
import LocalAuthentication
import Observation

@MainActor
@Observable
final class AppLock {
    var isUnlocked = false

    /// Face ID / Touch ID with automatic device-passcode fallback. Devices with
    /// no passcode configured are treated as unlocked (nothing to auth against).
    ///
    /// Simulators claim a device passcode exists even when none is set, which
    /// dead-ends at an unanswerable passcode sheet — so on the simulator use
    /// biometrics only: enroll via Features > Face ID > Enrolled to exercise the
    /// lock, otherwise it skips straight in.
    func authenticate() async {
        #if targetEnvironment(simulator)
        let policy: LAPolicy = .deviceOwnerAuthenticationWithBiometrics
        #else
        let policy: LAPolicy = .deviceOwnerAuthentication
        #endif

        // A fresh LAContext per attempt: reused contexts skip the prompt.
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(policy, error: &error) else {
            isUnlocked = true
            return
        }
        isUnlocked = (try? await context.evaluatePolicy(
            policy,
            localizedReason: "Unlock TrainMe"
        )) ?? false
    }

    func lock() {
        isUnlocked = false
    }
}
