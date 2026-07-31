import Foundation

public enum GuardFormatting {
    public static func bytes(_ value: UInt64) -> String {
        if value == 0 { return "0 MB" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: Int64(value))
    }

    public static func duration(_ seconds: Int) -> String {
        if seconds >= 86_400 {
            let days = seconds / 86_400
            let hours = (seconds % 86_400) / 3_600
            return "\(days)d \(hours)h"
        }
        if seconds >= 3_600 {
            return "\(seconds / 3_600)h \((seconds % 3_600) / 60)m"
        }
        if seconds >= 60 { return "\(seconds / 60)m" }
        return "\(seconds)s"
    }
}
