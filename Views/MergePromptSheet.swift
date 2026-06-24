import SwiftUI

/// Contextual bottom sheet shown when a dragged node is dropped near another.
struct MergePromptSheet: View {
    @ObservedObject var viewModel: CanvasViewModel
    let context: CanvasViewModel.MergeContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Text("Combine Tasks")
                .font(.headline)
                .padding(.top, 8)

            HStack(spacing: 8) {
                Text(context.dragged.title).bold().lineLimit(1)
                Image(systemName: "arrow.right")
                Text(context.target.title).bold().lineLimit(1)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                actionButton("Make Subtask", icon: "arrow.turn.down.right") {
                    viewModel.makeSubtask(draggedID: context.dragged.id, targetID: context.target.id)
                    dismiss()
                }
                actionButton("Swap Priority", icon: "arrow.left.arrow.right") {
                    viewModel.swapPriority(aID: context.dragged.id, bID: context.target.id)
                    dismiss()
                }
            }

            Button(role: .cancel) {
                dismiss()
            } label: {
                Text("Cancel").frame(maxWidth: .infinity)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .onDisappear { viewModel.mergeContext = nil }
    }

    private func actionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
                Spacer()
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .foregroundStyle(.primary)
    }
}
