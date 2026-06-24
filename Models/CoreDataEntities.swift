import CoreData

@objc(TaskEntity)
final class TaskEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var notes: String?
    @NSManaged var deadline: Date
    @NSManaged var priority: Int16
    @NSManaged var computedGravityWeight: Double
    @NSManaged var isCompleted: Bool
    @NSManaged var createdAt: Date
    @NSManaged var positionX: Double
    @NSManaged var positionY: Double
    @NSManaged var subtasks: Set<SubtaskEntity>?
}

extension TaskEntity {
    static func makeFetchRequest() -> NSFetchRequest<TaskEntity> {
        NSFetchRequest<TaskEntity>(entityName: "TaskEntity")
    }
}

@objc(SubtaskEntity)
final class SubtaskEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var isCompleted: Bool
    @NSManaged var createdAt: Date
    @NSManaged var parentTask: TaskEntity?
}

extension SubtaskEntity {
    static func makeFetchRequest() -> NSFetchRequest<SubtaskEntity> {
        NSFetchRequest<SubtaskEntity>(entityName: "SubtaskEntity")
    }
}

@objc(UserPreferencesEntity)
final class UserPreferencesEntity: NSManagedObject {
    @NSManaged var gravityMultiplier: Double
    @NSManaged var showCompletedTasks: Bool
}

extension UserPreferencesEntity {
    static func makeFetchRequest() -> NSFetchRequest<UserPreferencesEntity> {
        NSFetchRequest<UserPreferencesEntity>(entityName: "UserPreferencesEntity")
    }
}
