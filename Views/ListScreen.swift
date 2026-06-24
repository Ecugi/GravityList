import SwiftUI

/// Flat list of the same tasks, sorted by descending gravity weight. Reads the
/// same ViewModel as the canvas, so the two views stay in sync.
struct ListScreen: View {
    @ObservedObject var viewModel: CanvasViewModel
    @State private var pendingDelete: TaskItem?

    var body: some View {
        List {
            ForEach(viewModel.sortedByWeight) { item in
                Button {
                    viewModel.detailTaskID = item.id
                } label: {
                    row(for: item)
                }
                .listRowBackground(Color.white.opacity(0.05))
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        pendingDelete = item
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        viewModel.stepPriority(id: item.id, up: true)
                    } label: {
                        Label("Heavier", systemImage: "arrow.up")
                    }
                    .tint(.orange)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .padding(.top, 56)
        .confirmationDialog(
            "Delete this task?",
            isPresented: Binding(get: { pendingDelete != nil },
                                 set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { item in
            Button("Delete \(item.title)", role: .destructive) {
                viewModel.deleteTask(id: item.id)
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        }
    }

    private func row(for item: TaskItem) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color(for: item.priority))
                .frame(width: 14, height: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).foregroundStyle(.primary)
                Text(item.deadline, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(item.descriptor.rawValue)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }

    private func color(for priority: Int) -> Color {
        switch priority {
        case 2: return .red
        case 1: return .orange
        default: return .blue
        }
    }
}
