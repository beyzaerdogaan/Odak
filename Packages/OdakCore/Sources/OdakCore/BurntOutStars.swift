import Foundation

/// A point in the sky disc's bounding square, 0...1 on both axes, with the pole star at (0.5, 0.5).
public struct DiscPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

/// An area of the sky disc in the same units, such as a constellation's slot.
public struct DiscRect: Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
    public func contains(_ p: DiscPoint) -> Bool { p.x >= x && p.x <= x + width && p.y >= y && p.y <= y + height }
}

extension SkyProgress {
    /// Sessions the user gave up on. Each one stays in the sky as a burnt-out star.
    public var burntOutStars: [FocusRecord] { records.filter { !$0.completed } }
}

/// Where a burnt-out star sits in the sky disc. It depends only on the session's id, so it stays put across
/// launches and devices.
public enum BurntOutStarLayout {
    static let maxRadius = 0.46
    static let minRadius = 0.06

    public static func point(for id: UUID, avoiding: [DiscRect]) -> DiscPoint {
        let bytes = withUnsafeBytes(of: id.uuid) { Array($0) }
        let seed = bytes.enumerated().reduce(UInt64(0)) { $0 ^ (UInt64($1.element) << (UInt64($1.offset % 8) * 8)) }
        var rng = SeededGenerator(seed: seed)
        var candidate = DiscPoint(x: 0.5, y: 0.5 - maxRadius)
        for _ in 0..<64 {
            let r = sqrt(Double.random(in: 0...1, using: &rng)) * maxRadius
            guard r >= minRadius else { continue }
            let a = Double.random(in: 0..<(2 * .pi), using: &rng)
            candidate = DiscPoint(x: 0.5 + r * cos(a), y: 0.5 + r * sin(a))
            if !avoiding.contains(where: { $0.contains(candidate) }) { return candidate }
        }
        return candidate
    }
}
