import SwiftUI

/// The single root view. Hosts either the gravity canvas or the list view and
/// overlays the top controls and the floating add button.
struct RootView: View {
    @ObservedObject var viewModel: CanvasViewModel
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.10).ignoresSafeArea()

            if viewModel.isListView {
                ListScreen(viewModel: viewModel)
            } else {
                GravityCanvasView(viewModel: viewModel)
            }

            topControls

            if !viewModel.isListView {
                addButton
            }
        }
        .sheet(isPresented: $viewModel.showAddSheet) {
            AddTaskSheet(viewModel: viewModel)
        }
        .sheet(item: detailItem) { wrapper in
            TaskDetailSheet(viewModel: viewModel, taskID: wrapper.id)
        }
        .sheet(item: $viewModel.mergeContext) { context in
            MergePromptSheet(viewModel: viewModel, context: context)
                .presentationDetents([.height(260)])
        }
        .sheet(isPresented: $showSettings) {
            SettingsScreen(viewModel: viewModel)
        }
    }

    // MARK: - Overlays

    private var topControls: some View {
        VStack {
            HStack {
                Picker("View", selection: $viewModel.isListView) {
                    Image(systemName: "circle.hexagongrid.fill").tag(false)
                    Image(systemName: "list.bullet").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 130)

                Spacer()

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            Spacer()
        }
    }

    private var addButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    viewModel.showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(Color.accentColor))
                        .shadow(radius: 8)
                }
                .padding(24)
            }
        }
    }

    /// Bridges the optional `detailTaskID` into an `Identifiable` for `.sheet(item:)`.
    private var detailItem: Binding<IdentifiableUUID?> {
        Binding(
            get: { viewModel.detailTaskID.map(IdentifiableUUID.init) },
            set: { viewModel.detailTaskID = $0?.id }
        )
    }
}

struct IdentifiableUUID: Identifiable {
    let id: UUID
}
