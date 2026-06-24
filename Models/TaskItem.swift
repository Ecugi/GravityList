import Foundation

/// Immutable value snapshot of a `TaskEntity`. The ViewModel publishes an array
/// of these; both the SwiftUI List view and the SpriteKit scene render from them
/// so no `NSManagedObject` crosses into the physics layer.
struct TaskItem: Identifiable, Equatable {
    let id: UUID
    var title: String
    var notes: String
    var deadline: Date
    var priority: Int
    var isCompleted: Bool
    var positionX: Double
    var positionY: Double
    var subtaskCount: Int
    var weight: Double

    /// Whole days remaining until the deadline (rounded up). Negative/zero => due.
    var daysRemaining: Int {
        Int(ceil(deadline.timeIntervalSinceNow / 86_400))
    }

    var descriptor: GravityWeight.Descriptor {
        GravityWeight.descriptor(for: weight)
    }
}
