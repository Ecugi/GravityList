import SwiftUI

@main
struct GravityListApp: App {
    @StateObject private var store = StoreManager()
    @StateObject private var viewModel = CanvasViewModel(
        context: PersistenceController.shared.container.viewContext
    )

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: viewModel)
                .environmentObject(store)
                .environment(\.managedObjectContext,
                             PersistenceController.shared.container.viewContext)
                .preferredColorScheme(.dark)
        }
    }
}
