import Foundation
import LocalAuthentication

@MainActor
enum BiometricLock {
    static func unlock() async -> String? {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var probe: NSError?
        let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &probe)
            ? .deviceOwnerAuthenticationWithBiometrics
            : .deviceOwnerAuthentication
        do {
            let success = try await context.evaluatePolicy(policy, localizedReason: "Unlock Money Stalker")
            return success ? nil : "Money Stalker stayed locked."
        } catch {
            return error.localizedDescription
        }
    }
}
