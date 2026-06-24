import SpriteKit

/// A single circular "gravity node". Radius encodes weight, fill colour encodes
/// priority, and the labels overlay the title and days-remaining indicator.
final class TaskNode: SKNode {
    let id: UUID
    private(set) var weight: Double

    private let shape: SKShapeNode
    private let titleLabel: SKLabelNode
    private let deadlineLabel: SKLabelNode
    private var radius: CGFloat

    init(item: TaskItem) {
        id = item.id
        weight = item.weight
        radius = TaskNode.radius(for: item.weight)
        shape = SKShapeNode(circleOfRadius: radius)
        titleLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        deadlineLabel = SKLabelNode(fontNamed: "Helvetica")
        super.init()

        addChild(shape)
        configureLabels()
        addChild(titleLabel)
        addChild(deadlineLabel)
        apply(item)
        rebuildPhysicsBody(preservingVelocity: false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Geometry

    static func radius(for weight: Double) -> CGFloat {
        let minRadius: CGFloat = 26
        let maxRadius: CGFloat = 64
        return minRadius + CGFloat(weight / 100) * (maxRadius - minRadius)
    }

    private func configureLabels() {
        titleLabel.fontSize = 12
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.numberOfLines = 2
        titleLabel.preferredMaxLayoutWidth = radius * 1.7
        titleLabel.position = CGPoint(x: 0, y: 3)

        deadlineLabel.fontSize = 9
        deadlineLabel.fontColor = SKColor(white: 1, alpha: 0.85)
        deadlineLabel.verticalAlignmentMode = .center
        deadlineLabel.position = CGPoint(x: 0, y: -radius + 12)
    }

    private func color(for priority: Int) -> SKColor {
        switch priority {
        case 2:  return SKColor(red: 0.90, green: 0.26, blue: 0.27, alpha: 1) // high  -> red
        case 1:  return SKColor(red: 0.96, green: 0.70, blue: 0.20, alpha: 1) // medium-> amber
        default: return SKColor(red: 0.27, green: 0.55, blue: 0.92, alpha: 1) // low   -> blue
        }
    }

    private func apply(_ item: TaskItem) {
        shape.fillColor = color(for: item.priority)
        shape.strokeColor = SKColor(white: 1, alpha: 0.25)
        shape.lineWidth = 2
        titleLabel.text = item.title
        titleLabel.preferredMaxLayoutWidth = radius * 1.7
        let days = item.daysRemaining
        deadlineLabel.text = days <= 0 ? "due" : "\(days)d"
    }

    private func rebuildPhysicsBody(preservingVelocity: Bool) {
        let previousVelocity = physicsBody?.velocity
        let body = SKPhysicsBody(circleOfRadius: radius)
        body.affectedByGravity = false
        body.allowsRotation = false
        body.restitution = 0.1
        body.friction = 0.3
        body.linearDamping = 1.6
        body.mass = CGFloat(0.4 + weight / 100) // heavier weight => more massive
        if preservingVelocity, let previousVelocity { body.velocity = previousVelocity }
        physicsBody = body
    }

    // MARK: - Updates

    func update(with item: TaskItem) {
        let newRadius = TaskNode.radius(for: item.weight)
        let geometryChanged = abs(newRadius - radius) > 0.5
        weight = item.weight
        if geometryChanged {
            radius = newRadius
            shape.path = CGPath(ellipseIn: CGRect(x: -radius, y: -radius,
                                                  width: radius * 2, height: radius * 2),
                                transform: nil)
            deadlineLabel.position = CGPoint(x: 0, y: -radius + 12)
            rebuildPhysicsBody(preservingVelocity: true)
        }
        apply(item)
    }

    func dropIn() {
        setScale(0.1)
        alpha = 0
        run(.group([.scale(to: 1, duration: 0.3), .fadeIn(withDuration: 0.3)]))
    }

    func setDragging(_ dragging: Bool) {
        physicsBody?.isDynamic = !dragging
        run(.scale(to: dragging ? 1.18 : 1.0, duration: 0.12))
        shape.glowWidth = dragging ? 8 : 0
    }
}
