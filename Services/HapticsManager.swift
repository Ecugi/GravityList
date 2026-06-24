import CoreHaptics
import Foundation

/// Thin wrapper around CoreHaptics. Every entry point degrades silently on
/// devices without haptic hardware (e.g. iPad, Simulator) — no crashes, no errors.
final class HapticsManager {
    static let shared = HapticsManager()

    private let supportsHaptics: Bool
    private var engine: CHHapticEngine?
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?

    private init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        prepareEngine()
    }

    private func prepareEngine() {
        guard supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = true
            engine.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            engine.stoppedHandler = { _ in }
            try engine.start()
            self.engine = engine
        } catch {
            engine = nil
        }
    }

    @discardableResult
    private func ensureRunning() -> Bool {
        guard supportsHaptics, let engine else { return false }
        do { try engine.start(); return true } catch { return false }
    }

    // MARK: - Transients

    /// Swipe weight change: a single crisp tap.
    func transientTap(intensity: Float = 0.7, sharpness: Float = 0.6) {
        guard ensureRunning() else { return }
        playTransient(intensity: intensity, sharpness: sharpness)
    }

    /// Task deletion: a heavy impact.
    func impact() {
        guard ensureRunning() else { return }
        playTransient(intensity: 1.0, sharpness: 0.9)
    }

    /// Merge confirmation: a light, sharp click.
    func click() {
        guard ensureRunning() else { return }
        playTransient(intensity: 0.55, sharpness: 1.0)
    }

    /// Swap priority: two sequential taps.
    func doubleTap() {
        guard ensureRunning() else { return }
        playTransient(intensity: 0.6, sharpness: 0.7, relativeTime: 0)
        playTransient(intensity: 0.6, sharpness: 0.7, relativeTime: 0.12)
    }

    private func playTransient(intensity: Float, sharpness: Float, relativeTime: TimeInterval = 0) {
        guard let engine else { return }
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: relativeTime
        )
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Ignore — haptics are non-essential feedback.
        }
    }

    // MARK: - Continuous drag rumble

    /// Low-frequency rumble while dragging a node; intensity ~ node mass (0...1).
    func startContinuousRumble(intensity: Float) {
        guard ensureRunning(), let engine else { return }
        stopContinuousRumble()
        let value = max(0.1, min(1.0, intensity))
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: value),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
            ],
            relativeTime: 0,
            duration: 30
        )
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makeAdvancedPlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            continuousPlayer = player
        } catch {
            continuousPlayer = nil
        }
    }

    /// Live-update the rumble intensity as the dragged node's mass changes.
    func updateContinuousRumble(intensity: Float) {
        guard supportsHaptics, let player = continuousPlayer else { return }
        let value = max(0.1, min(1.0, intensity))
        let param = CHHapticDynamicParameter(
            parameterID: .hapticIntensityControl,
            value: value,
            relativeTime: 0
        )
        try? player.sendParameters([param], atTime: CHHapticTimeImmediate)
    }

    func stopContinuousRumble() {
        guard let player = continuousPlayer else { return }
        try? player.stop(atTime: CHHapticTimeImmediate)
        continuousPlayer = nil
    }
}
