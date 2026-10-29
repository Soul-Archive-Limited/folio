import Foundation
import UIKit

/// What Profile → Devices calls this device: model and OS, e.g. "iPhone 15 Pro · iOS 27.1"
/// (Batch F). iOS doesn't share the person's own device name with apps (DECISIONS 181), so
/// the person can give any device a name of their own, sealed with the Data Key.
nonisolated enum DeviceInfo {
    @MainActor static var name: String {
        let device = UIDevice.current
        let os = "\(device.systemName) \(device.systemVersion)"
        #if targetEnvironment(simulator)
        return "Simulator · \(os)"
        #else
        return "\(modelName(identifier: machineIdentifier, fallback: device.model)) · \(os)"
        #endif
    }

    /// "iPhone16,1" and the like.
    static var machineIdentifier: String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    /// Marketing names for the iPhones iOS 26 runs on; anything newer falls back to "iPhone".
    static func modelName(identifier: String, fallback: String) -> String {
        models[identifier] ?? fallback
    }

    private static let models: [String: String] = [
        "iPhone12,1": "iPhone 11", "iPhone12,3": "iPhone 11 Pro", "iPhone12,5": "iPhone 11 Pro Max", "iPhone12,8": "iPhone SE",
        "iPhone13,1": "iPhone 12 mini", "iPhone13,2": "iPhone 12", "iPhone13,3": "iPhone 12 Pro", "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,4": "iPhone 13 mini", "iPhone14,5": "iPhone 13", "iPhone14,2": "iPhone 13 Pro", "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,6": "iPhone SE", "iPhone14,7": "iPhone 14", "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro", "iPhone15,3": "iPhone 14 Pro Max", "iPhone15,4": "iPhone 15", "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro", "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,1": "iPhone 16 Pro", "iPhone17,2": "iPhone 16 Pro Max", "iPhone17,3": "iPhone 16", "iPhone17,4": "iPhone 16 Plus",
        "iPhone17,5": "iPhone 16e",
        "iPhone18,1": "iPhone 17 Pro", "iPhone18,2": "iPhone 17 Pro Max", "iPhone18,3": "iPhone 17", "iPhone18,4": "iPhone Air",
    ]
}
