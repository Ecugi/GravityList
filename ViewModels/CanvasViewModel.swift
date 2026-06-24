import CoreData
import SwiftUI

/// Single source of truth for the canvas. Owns the CoreData context, derives
/// each task's gravity weight, exposes immutable `TaskItem` snapshots, and routes
/// modal presentation.
final class CanvasViewModel: ObservableObject {
    @Published private(set) var tasks: [TaskItem] = []
    @Published private(set) var gravityMultiplier: Double = 1.0
    @Published private(set) var showCompletedTasks = false

    // Modal / view routing
    @Published var showAddSheet = false
    @Published var detailTaskID: UUID?
    @Published var mergeContext: MergeContext?
    @Published var isListView = false
    /// Bumped to ask the live scene to re-randomise node positions.
    @Published var resetCounter = 0

    struct MergeContext: Identifiable {
        let id = UUID()
        let dragged: TaskItem
        let target: TaskItem
    }

    let context: NSManagedObjectContext
    private var preferences: UserPreferencesEntity?

    init(context: NSManagedObjectContext) {
        self.context = context
        loadPreferences()
        reload()
    }

    // MARK: - Preferences

    private func loadPreferences() {
        let request = UserPreferencesEntity.makeFetchRequest()
        request.fetchLimit = 1
        if let existing = try? context.fetch(request).first {
            preferences = existing
        } else {
            let prefs = UserPreferencesEntity(context: context)
            prefs.gravityMultiplier = 1.0
            prefs.showCompletedTasks = false
            preferences = prefs
            save()
        }
        gravityMultiplier = preferences?.gravityMultiplier ?? 1.0
        showCompletedTasks = preferences?.showCompletedTasks ?? false
    }

    func setGravityMultiplier(_ value: Double) {
        gravityMultiplier = value
        preferences?.gravityMultiplier = value
        save()
    }

    func setShowCompleted(_ value: Bool) {
        showCompletedTasks = value
        preferences?.showCompletedTasks = value
        save()
        reload()
    }

    func resetScene() {
        resetCounter += 1
    }

    // MARK: - Fetch / derive

    func reload() {
        let request = TaskEntity.makeFetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        let entities = (try? context.fetch(request)) ?? []
        let now = Date()

        tasks = entities.compactMap { entity in
            if entity.isCompleted && !showCompletedTasks { return nil }
            let weight = GravityWeight.weight(deadline: entity.deadline,
                                              priority: Int(entity.priority),
                                              now: now)
            if abs(entity.computedGravityWeight - weight) > 0.001 {
                entity.computedGravityWeight = weight // cache derived value
            }
            return TaskItem(id: entity.id,
                            title: entity.title,
                            notes: entity.notes ?? "",
                            deadline: entity.deadline,
                            priority: Int(entity.priority),
                            isCompleted: entity.isCompleted,
                            positionX: entity.positionX,
                            positionY: entity.positionY,
                            subtaskCount: entity.subtasks?.count ?? 0,
                            weight: weight)
        }
        if context.hasChanges { save() }
    }

    var sortedByWeight: [TaskItem] {
        tasks.sorted { $0.weight > $1.weight }
    }

    func task(_ id: UUID) -> TaskItem? {
        tasks.first { $0.id == id }
    }

    private func entity(_ id: UUID) -> TaskEntity? {
        let request = TaskEntity.makeFetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    // MARK: - Task mutations

    @discardableResult
    func addTask(title: String, deadline: Date, priority: Int, notes: String) -> TaskItem? {
        let entity = TaskEntity(context: context)
        entity.id = UUID()
        entity.title = title
        entity.deadline = deadline
        entity.priority = Int16(priority)
        entity.notes = notes.isEmpty ? nil : notes
        entity.isCompleted = false
        entity.createdAt = Date()
        entity.positionX = 0
        entity.positionY = 0
        entity.computedGravityWeight = GravityWeight.weight(deadline: deadline, priority: priority)
        save()
        reload()
        return task(entity.id)
    }

    func updateTask(id: UUID, title: String, deadline: Date, priority: Int, notes: String) {
        guard let entity = entity(id) else { return }
        entity.title = title
        entity.deadline = deadline
        entity.priority = Int16(priority)
        entity.notes = notes.isEmpty ? nil : notes
        save()
        reload()
    }

    func deleteTask(id: UUID) {
        guard let entity = entity(id) else { return }
        context.delete(entity)
        save()
        reload()
        HapticsManager.shared.impact()
    }

    /// Swipe handling: right raises priority one step, left lowers it one step.
    /// Lowering below "low" removes the task from physics (archived/completed).
    func stepPriority(id: UUID, up: Bool) {
        guard let entity = entity(id) else { return }
        let current = Int(entity.priority)
        if up {
            entity.priority = Int16(min(2, current + 1))
        } else if current == 0 {
            entity.isCompleted = true // low -> none: leaves the physics scene
        } else {
            entity.priority = Int16(max(0, current - 1))
        }
        save()
        reload()
        HapticsManager.shared.transientTap()
    }

    /// Persist a dropped node's last canvas position without triggering a reload.
    func updatePosition(id: UUID, x: Double, y: Double) {
        guard let entity = entity(id) else { return }
        entity.positionX = x
        entity.positionY = y
        save()
    }

    // MARK: - Merge actions

    func makeSubtask(draggedID: UUID, targetID: UUID) {
        guard let dragged = entity(draggedID), let target = entity(targetID) else { return }
        let subtask = SubtaskEntity(context: context)
        subtask.id = UUID()
        subtask.title = dragged.title
        subtask.isCompleted = dragged.isCompleted
        subtask.createdAt = Date()
        subtask.parentTask = target
        context.delete(dragged)
        // Added complexity makes the target heavier (larger radius).
        target.priority = Int16(min(2, Int(target.priority) + 1))
        save()
        reload()
        HapticsManager.shared.click()
    }

    func swapPriority(aID: UUID, bID: UUID) {
        guard let a = entity(aID), let b = entity(bID) else { return }
        let tmp = a.priority
        a.priority = b.priority
        b.priority = tmp
        save()
        reload()
        HapticsManager.shared.doubleTap()
    }

    // MARK: - Subtasks

    func subtasks(of taskID: UUID) -> [SubtaskEntity] {
        guard let entity = entity(taskID) else { return [] }
        return (entity.subtasks ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    func addSubtask(to taskID: UUID, title: String) {
        guard let entity = entity(taskID) else { return }
        let subtask = SubtaskEntity(context: context)
        subtask.id = UUID()
        subtask.title = title
        subtask.isCompleted = false
        subtask.createdAt = Date()
        subtask.parentTask = entity
        save()
        reload()
    }

    func toggleSubtask(_ subtaskID: UUID, in taskID: UUID) {
        guard let entity = entity(taskID),
              let subtask = (entity.subtasks ?? []).first(where: { $0.id == subtaskID }) else { return }
        subtask.isCompleted.toggle()
        save()
        objectWillChange.send()
    }

    // MARK: - Persistence

    private func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            context.rollback()
        }
    }
}
