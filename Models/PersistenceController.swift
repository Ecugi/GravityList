import CoreData

/// Builds the CoreData stack with a model defined entirely in code.
/// Using a programmatic `NSManagedObjectModel` keeps the project a clean
/// single target with no `.xcdatamodeld` resource to package, while still
/// being genuine on-device CoreData persistence (no external dependencies).
final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        let model = PersistenceController.makeModel()
        container = NSPersistentContainer(name: "GravityList", managedObjectModel: model)

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error = error {
                assertionFailure("CoreData failed to load store: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Programmatic model

    static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let task = NSEntityDescription()
        task.name = "TaskEntity"
        task.managedObjectClassName = NSStringFromClass(TaskEntity.self)

        let subtask = NSEntityDescription()
        subtask.name = "SubtaskEntity"
        subtask.managedObjectClassName = NSStringFromClass(SubtaskEntity.self)

        let prefs = NSEntityDescription()
        prefs.name = "UserPreferencesEntity"
        prefs.managedObjectClassName = NSStringFromClass(UserPreferencesEntity.self)

        func attribute(_ name: String,
                       _ type: NSAttributeType,
                       optional: Bool = false,
                       defaultValue: Any? = nil) -> NSAttributeDescription {
            let attr = NSAttributeDescription()
            attr.name = name
            attr.attributeType = type
            attr.isOptional = optional
            if let defaultValue { attr.defaultValue = defaultValue }
            return attr
        }

        task.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("title", .stringAttributeType, defaultValue: ""),
            attribute("notes", .stringAttributeType, optional: true),
            attribute("deadline", .dateAttributeType),
            attribute("priority", .integer16AttributeType, defaultValue: 0),
            attribute("computedGravityWeight", .doubleAttributeType, defaultValue: 0.0),
            attribute("isCompleted", .booleanAttributeType, defaultValue: false),
            attribute("createdAt", .dateAttributeType),
            attribute("positionX", .doubleAttributeType, defaultValue: 0.0),
            attribute("positionY", .doubleAttributeType, defaultValue: 0.0)
        ]

        subtask.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("title", .stringAttributeType, defaultValue: ""),
            attribute("isCompleted", .booleanAttributeType, defaultValue: false),
            attribute("createdAt", .dateAttributeType)
        ]

        prefs.properties = [
            attribute("gravityMultiplier", .doubleAttributeType, defaultValue: 1.0),
            attribute("showCompletedTasks", .booleanAttributeType, defaultValue: false)
        ]

        // Task <->> Subtask relationship
        let taskToSubtasks = NSRelationshipDescription()
        taskToSubtasks.name = "subtasks"
        taskToSubtasks.destinationEntity = subtask
        taskToSubtasks.minCount = 0
        taskToSubtasks.maxCount = 0 // 0 == to-many
        taskToSubtasks.deleteRule = .cascadeDeleteRule
        taskToSubtasks.isOptional = true

        let subtaskToTask = NSRelationshipDescription()
        subtaskToTask.name = "parentTask"
        subtaskToTask.destinationEntity = task
        subtaskToTask.minCount = 0
        subtaskToTask.maxCount = 1
        subtaskToTask.deleteRule = .nullifyDeleteRule
        subtaskToTask.isOptional = true

        taskToSubtasks.inverseRelationship = subtaskToTask
        subtaskToTask.inverseRelationship = taskToSubtasks

        task.properties.append(taskToSubtasks)
        subtask.properties.append(subtaskToTask)

        model.entities = [task, subtask, prefs]
        return model
    }
}
