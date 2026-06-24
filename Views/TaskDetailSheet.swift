import SwiftUI

struct TaskDetailSheet: View {
    @ObservedObject var viewModel: CanvasViewModel
    @EnvironmentObject var store: StoreManager
    let taskID: UUID

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var deadline = Date()
    @State private var priority = 0
    @State private var notes = ""
    @State private var newSubtask = ""
    @State private var loaded = false
    @State private var showDiscard = false
    @State private var showUpsell = false

    private var task: TaskItem? { viewModel.task(taskID) }

    private var hasEdits: Bool {
        guard let task else { return false }
        return title != task.title
            || priority != task.priority
            || notes != task.notes
            || !Calendar.current.isDate(deadline, equalTo: task.deadline, toGranularity: .minute)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                    DatePicker("Deadline", selection: $deadline)
                    Picker("Priority", selection: $priority) {
                        Text("Low").tag(0)
                        Text("Medium").tag(1)
                        Text("High").tag(2)
                    }
                    .pickerStyle(.segmented)
                    if let task {
                        LabeledContent("Gravity Weight", value: task.descriptor.rawValue)
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                subtaskSection

                Section {
                    Button(role: .destructive) {
                        viewModel.deleteTask(id: taskID)
                        dismiss()
                    } label: {
                        Label("Delete Task", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        if hasEdits { showDiscard = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.updateTask(id: taskID,
                                             title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                             deadline: deadline,
                                             priority: priority,
                                             notes: notes)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog("Discard changes?", isPresented: $showDiscard) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            }
            .alert("Pro Required", isPresented: $showUpsell) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Upgrade to GravityList Pro in Settings to add subtasks.")
            }
            .onAppear(perform: loadIfNeeded)
        }
    }

    private var subtaskSection: some View {
        Section("Subtasks") {
            ForEach(viewModel.subtasks(of: taskID), id: \.id) { subtask in
                Button {
                    viewModel.toggleSubtask(subtask.id, in: taskID)
                } label: {
                    HStack {
                        Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(subtask.isCompleted ? .green : .secondary)
                        Text(subtask.title)
                            .strikethrough(subtask.isCompleted)
                            .foregroundStyle(subtask.isCompleted ? .secondary : .primary)
                    }
                }
            }

            HStack {
                TextField("New subtask", text: $newSubtask)
                Button {
                    addSubtask()
                } label: {
                    Image(systemName: store.isPro ? "plus.circle.fill" : "lock.fill")
                }
                .buttonStyle(.borderless)
            }

            if !store.isPro {
                Text("Subtasks are a Pro feature.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func addSubtask() {
        guard store.isPro else {
            showUpsell = true
            return
        }
        let trimmed = newSubtask.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.addSubtask(to: taskID, title: trimmed)
        newSubtask = ""
    }

    private func loadIfNeeded() {
        guard !loaded, let task else { return }
        title = task.title
        deadline = task.deadline
        priority = task.priority
        notes = task.notes
        loaded = true
    }
}
