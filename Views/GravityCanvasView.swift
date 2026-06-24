import SwiftUI
import SpriteKit

/// Hosts the SpriteKit `GravityScene` and keeps it in sync with the ViewModel.
struct GravityCanvasView: View {
    @ObservedObject var viewModel: CanvasViewModel
    @StateObject private var holder = SceneHolder()

    var body: some View {
        GeometryReader { geo in
            SpriteView(scene: holder.scene(size: geo.size, viewModel: viewModel),
                       options: [.ignoresSiblingOrder])
                .ignoresSafeArea()
                .onAppear {
                    holder.connect(viewModel)
                    holder.sync(viewModel.tasks)
                }
                .onChange(of: viewModel.tasks) { _, newValue in
                    holder.sync(newValue)
                }
                .onChange(of: viewModel.gravityMultiplier) { _, value in
                    holder.setGravity(value)
                }
                .onChange(of: viewModel.resetCounter) { _, _ in
                    holder.reset()
                }
        }
    }
}

/// Retains the single scene instance and its delegate bridge across SwiftUI
/// re-renders so the simulation isn't rebuilt every frame.
final class SceneHolder: ObservableObject {
    private var scene: GravityScene?
    private var bridge: SceneBridge?

    func scene(size: CGSize, viewModel: CanvasViewModel) -> GravityScene {
        if let scene {
            if size.width > 0, scene.size != size { scene.size = size }
            return scene
        }
        let resolved = (size.width > 0 && size.height > 0) ? size : CGSize(width: 390, height: 800)
        let newScene = GravityScene(size: resolved)
        newScene.scaleMode = .resizeFill
        newScene.gravityMultiplier = CGFloat(viewModel.gravityMultiplier)
        let newBridge = SceneBridge(viewModel: viewModel)
        newScene.interactionDelegate = newBridge
        scene = newScene
        bridge = newBridge
        return newScene
    }

    func connect(_ viewModel: CanvasViewModel) {
        bridge?.viewModel = viewModel
        scene?.interactionDelegate = bridge
        scene?.gravityMultiplier = CGFloat(viewModel.gravityMultiplier)
    }

    func sync(_ items: [TaskItem]) { scene?.sync(items) }
    func setGravity(_ value: Double) { scene?.gravityMultiplier = CGFloat(value) }
    func reset() { scene?.resetPositions() }
}

/// Translates scene callbacks into ViewModel calls. Holds the ViewModel weakly
/// to avoid a retain cycle (scene -> bridge -> viewModel).
final class SceneBridge: GravitySceneDelegate {
    weak var viewModel: CanvasViewModel?

    init(viewModel: CanvasViewModel) {
        self.viewModel = viewModel
    }

    func sceneDidTapTask(_ id: UUID) {
        viewModel?.detailTaskID = id
    }

    func sceneDidSwipeTask(_ id: UUID, up: Bool) {
        viewModel?.stepPriority(id: id, up: up)
    }

    func sceneDidRequestMerge(dragged: UUID, target: UUID) {
        guard let viewModel,
              let draggedItem = viewModel.task(dragged),
              let targetItem = viewModel.task(target) else { return }
        viewModel.mergeContext = CanvasViewModel.MergeContext(dragged: draggedItem, target: targetItem)
    }

    func sceneDidMoveTask(_ id: UUID, to point: CGPoint) {
        viewModel?.updatePosition(id: id, x: Double(point.x), y: Double(point.y))
    }

    func sceneDragMass(for id: UUID) -> CGFloat {
        CGFloat((viewModel?.task(id)?.weight ?? 50) / 100)
    }
}
