import Foundation
import LocalAuthentication

/// AlfaGram: Face ID / Touch ID, with the device passcode as the fallback (for locked chats and hidden accounts).
public enum AlfaAuth {
    /// Calls `completion` on the main queue. A device without any passcode cannot check anything, so it passes.
    public static func authenticate(reason: String, completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            completion(true)
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason, reply: { success, _ in
            DispatchQueue.main.async {
                completion(success)
            }
        })
    }
}
