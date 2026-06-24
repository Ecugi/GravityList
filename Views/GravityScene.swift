import SpriteKit
import UIKit

/// Callbacks the scene fires back into SwiftUI/the ViewModel.
protocol GravitySceneDelegate: AnyObject {
    func sceneDidTapTask(_ id: UUID)
    func sceneDidSwipeTask(_ id: UUID, up: Bool)
    func sceneDidRequestMerge(dragged: UUID, target: UUID)
    func sceneDidMoveTask(_ id: UUID, to point: CGPoint)
    func sceneDragMass(for id: UUID) -> CGFloat // 0...1, for haptic intensity
}

/// The live physics canvas. Gravity is simulated by spring-pulling each node
/// toward a vertical target derived from its weight (heavier => lower), so heavier
/// nodes always settle below lighter ones while still colliding and drifting.
final class GravityScene: SKScene {
    weak var interactionDelegate: GravitySceneDelegate?
    var gravityMultiplier: CGFloat = 1.0

    private var taskNodes: [UUID: TaskNode] = [:]
    private let mergeRadius: CGFloat = 72

    // Gesture state
    private var activeNode: TaskNode?
    private var touchStart: CGPoint = .zero
    private var touchStartTime: TimeInterval = 0
    private var isDragging = false
    private let longPressThreshold: TimeInterval = 0.25
    private let dragMoveThreshold: CGFloat = 14
    private let swipeThreshold: CGFloat = 50

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.05, green: 0.06, blue: 0.10, alpha: 1)
        scaleMode = .resizeFill
        physicsWorld.gravity = .zero
        installBoundary()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        installBoundary()
    }

    private func installBoundary() {
        guard size.width > 0, size.height > 0 else { return }
        let body = SKPhysicsBody(edgeLoopFrom: CGRect(origin: .zero, size: size))
        body.friction = 0.2
        body.restitution = 0.1
        physicsBody = body
    }

    // MARK: - Sync from ViewModel

    func sync(_ items: [TaskItem]) {
        let physicsItems = items.filter { !$0.isCompleted }
        let liveIDs = Set(physicsItems.map { $0.id })

        // Dissolve removed nodes.
        for (id, node) in taskNodes where !liveIDs.contains(id) {
            taskNodes[id] = nil
            node.removeAllActions()
            node.physicsBody = nil
            node.run(.sequence([
                .group([.fadeOut(withDuration: 0.35), .scale(to: 0.1, duration: 0.35)]),
                .removeFromParent()
            ]))
        }

        for item in physicsItems {
            if let node = taskNodes[item.id] {
                node.update(with: item)
            } else {
                let node = TaskNode(item: item)
                node.position = spawnPoint(for: item)
                taskNodes[item.id] = node
                addChild(node)
                node.dropIn()
            }
        }
    }

    private func spawnPoint(for item: TaskItem) -> CGPoint {
        if item.positionX > 0, item.positionY > 0,
           item.positionX < size.width, item.positionY < size.height {
            return CGPoint(x: item.positionX, y: item.positionY)
        }
        let x = CGFloat.random(in: size.width * 0.2 ... size.width * 0.8)
        return CGPoint(x: x, y: size.height - 40) // drop in from the top
    }

    func resetPositions() {
        for node in taskNodes.values {
            node.physicsBody?.velocity = .zero
            node.position = CGPoint(
                x: .random(in: size.width * 0.15 ... size.width * 0.85),
                y: .random(in: size.height * 0.4 ... size.height * 0.9)
            )
        }
    }

    // MARK: - Physics

    override func update(_ currentTime: TimeInterval) {
        guard size.height > 0 else { return }
        let bottom: CGFloat = 70
        let top = size.height - 70
        let span = max(1, top - bottom)

        for node in taskNodes.values {
            guard let body = node.physicsBody, body.isDynamic else { continue }
            let normalized = CGFloat(node.weight) / 100        // 0...1
            let targetY = bottom + (1 - normalized) * span      // heavy => low
            let dy = targetY - node.position.y
            let k: CGFloat = 0.9 * gravityMultiplier
            body.applyForce(CGVector(dx: 0, dy: dy * k * body.mass))
            // Gentle horizontal centring so nodes don't stack in the corners.
            let dx = (size.width / 2 - node.position.x) * 0.02
            body.applyForce(CGVector(dx: dx * body.mass, dy: 0))
        }
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        touchStart = point
        touchStartTime = touch.timestamp
        isDragging = false
        activeNode = taskNode(at: point)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let node = activeNode else { return }
        let point = touch.location(in: self)
        let distance = hypot(point.x - touchStart.x, point.y - touchStart.y)
        let elapsed = touch.timestamp - touchStartTime

        if !isDragging, elapsed >= longPressThreshold, distance >= dragMoveThreshold {
            beginDrag(node)
        }
        if isDragging {
            node.position = point
            node.physicsBody?.velocity = .zero
            applyDragField(around: node)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer { isDragging = false; activeNode = nil }
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        let elapsed = touch.timestamp - touchStartTime
        let totalDx = point.x - touchStart.x
        let totalDy = point.y - touchStart.y

        if isDragging, let node = activeNode {
            endDrag(node, at: point)
        } else if let node = activeNode {
            if abs(totalDx) > swipeThreshold, abs(totalDx) > abs(totalDy) {
                interactionDelegate?.sceneDidSwipeTask(node.id, up: totalDx > 0)
            } else if elapsed < 0.35, hypot(totalDx, totalDy) < dragMoveThreshold {
                interactionDelegate?.sceneDidTapTask(node.id)
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isDragging, let node = activeNode {
            node.setDragging(false)
            HapticsManager.shared.stopContinuousRumble()
        }
        isDragging = false
        activeNode = nil
    }

    private func beginDrag(_ node: TaskNode) {
        isDragging = true
        node.setDragging(true)
        let mass = interactionDelegate?.sceneDragMass(for: node.id) ?? 0.5
        HapticsManager.shared.startContinuousRumble(intensity: Float(mass))
    }

    private func endDrag(_ node: TaskNode, at point: CGPoint) {
        node.setDragging(false)
        HapticsManager.shared.stopContinuousRumble()
        if let target = nearestNode(to: node, within: mergeRadius) {
            interactionDelegate?.sceneDidRequestMerge(dragged: node.id, target: target.id)
        } else {
            interactionDelegate?.sceneDidMoveTask(node.id, to: point)
        }
    }

    /// While dragging, other nodes repel (if lighter) or attract (if heavier)
    /// relative to the dragged node's mass.
    private func applyDragField(around dragged: TaskNode) {
        for node in taskNodes.values where node !== dragged {
            let dx = node.position.x - dragged.position.x
            let dy = node.position.y - dragged.position.y
            let distance = max(20, hypot(dx, dy))
            guard distance < 170 else { continue }
            let relativeMass = CGFloat(node.weight - dragged.weight) / 100
            let direction = CGVector(dx: dx / distance, dy: dy / distance)
            // Lighter than dragged => push away; heavier => pull in.
            let magnitude = (-relativeMass) * 6 * (170 - distance)
            node.physicsBody?.applyForce(CGVector(dx: direction.dx * magnitude,
                                                  dy: direction.dy * magnitude))
        }
    }

    // MARK: - Hit testing

    private func taskNode(at point: CGPoint) -> TaskNode? {
        for hit in nodes(at: point) {
            if let task = hit as? TaskNode { return task }
            if let task = hit.parent as? TaskNode { return task }
        }
        return nearestNode(to: point, within: 50)
    }

    private func nearestNode(to node: TaskNode, within radius: CGFloat) -> TaskNode? {
        nearestNode(to: node.position, within: radius, excluding: node)
    }

    private func nearestNode(to point: CGPoint, within radius: CGFloat, excluding: TaskNode? = nil) -> TaskNode? {
        var best: TaskNode?
        var bestDistance = radius
        for node in taskNodes.values where node !== excluding {
            let distance = hypot(node.position.x - point.x, node.position.y - point.y)
            if distance < bestDistance {
                bestDistance = distance
                best = node
            }
        }
        return best
    }
}
