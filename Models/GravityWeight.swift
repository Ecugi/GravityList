import Foundation

/// Pure functions that derive a task's physics "weight" from its deadline and
/// priority. Weight is what the SpriteKit scene maps to node radius and mass.
///
/// Rule: urgency (fewer days until the deadline => higher) is multiplied by a
/// priority coefficient (high = 3, medium = 2, low = 1), then normalised to a
/// 0–100 scale.
enum GravityWeight {
    /// Tasks further out than this many days contribute no urgency.
    static let horizonDays: Double = 30

    static func weight(deadline: Date, priority: Int, now: Date = Date()) -> Double {
        let days = max(0, deadline.timeIntervalSince(now) / 86_400)
        let clamped = min(days, horizonDays)
        let urgency = (horizonDays - clamped) / horizonDays // 0...1, closer => larger

        let coefficient: Double
        switch priority {
        case 2: coefficient = 3   // high
        case 1: coefficient = 2   // medium
        default: coefficient = 1  // low
        }

        let raw = urgency * coefficient            // 0...3
        return (raw / 3.0) * 100.0                 // 0...100
    }

    enum Descriptor: String {
        case featherweight = "Featherweight"
        case standard = "Standard"
        case heavy = "Heavy"
        case critical = "Critical"
    }

    static func descriptor(for weight: Double) -> Descriptor {
        switch weight {
        case ..<25: return .featherweight
        case ..<50: return .standard
        case ..<75: return .heavy
        default: return .critical
        }
    }
}
