import Foundation

enum Format {
    /// 4:05 or 1:02:03
    static func clock(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    /// 52 min or 1h 12m
    static func duration(_ interval: TimeInterval) -> String {
        let minutes = Int(max(0, interval) / 60)
        let h = minutes / 60, m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m) min"
    }

    static func weight(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    static func weight(_ value: Double, _ unit: WeightUnit) -> String {
        "\(weight(value)) \(unit.symbol)"
    }

    static func set(_ set: SetEntry) -> String {
        "\(weight(set.weight)) × \(set.reps)"
    }
}
