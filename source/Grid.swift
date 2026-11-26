import Foundation

enum Grid {
    static func clearance(spacing: Int) -> Int { max(1, spacing - max(6, spacing / 10)) }
    static func blocked(_ slot: (Int, Int), by occupied: [(Int, Int)], clearance: Int) -> Bool {
        occupied.contains { abs($0.0 - slot.0) < clearance && abs($0.1 - slot.1) < clearance }
    }
    static func slots(left: Int, right: Int, top: Int, bottom: Int, spacing: Int, direction: String) -> [(Int, Int)] {
        guard left <= right, top <= bottom, spacing > 0 else { return [] }
        let xs = Array(stride(from: left, through: right, by: spacing))
        let ys = Array(stride(from: top, through: bottom, by: spacing))
        switch direction {
        case "Right": return stride(from: right, through: left, by: -spacing).flatMap { x in ys.map { (x, $0) } }
        case "Top": return ys.flatMap { y in xs.map { ($0, y) } }
        case "Bottom": return stride(from: bottom, through: top, by: -spacing).flatMap { y in xs.map { ($0, y) } }
        default: return xs.flatMap { x in ys.map { (x, $0) } }
        }
    }
    // Compact into the first N slots while preserving relative axis order.
    static func preservedSlots(points: [(Int, Int)], slots: [(Int, Int)], direction: String) -> [(Int, Int)]? {
        guard points.count <= slots.count else { return nil }
        guard !points.isEmpty else { return [] }
        let vertical = direction == "Left" || direction == "Right"
        func lane(_ p: (Int, Int)) -> Int { vertical ? p.0 : p.1 }
        func axis(_ p: (Int, Int)) -> Int { vertical ? p.1 : p.0 }
        // Preserve lane order on repeated alignment, including partially filled lanes.
        let existing = points.compactMap { p in slots.firstIndex { $0 == p } }
        let order: [Int]
        if existing.count == points.count && Set(existing).count == points.count {
            order = points.indices.sorted { existing[$0] < existing[$1] }
        } else {
            order = points.indices.sorted { a, b in
                if axis(points[a]) != axis(points[b]) { return axis(points[a]) < axis(points[b]) }
                if lane(points[a]) != lane(points[b]) {
                    return direction == "Right" || direction == "Bottom" ? lane(points[a]) > lane(points[b]) : lane(points[a]) < lane(points[b])
                }
                return a < b
            }
        }
        var result = points
        for (i, id) in order.enumerated() { result[id] = slots[i] }
        return result
    }
}

struct UpdateFeed: Decodable {
    let version: String
    let release_notes: String
}
extension LeftDeskVersion {
    static func validVersion(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        return (1...4).contains(parts.count) && parts.allSatisfy { !$0.isEmpty && $0.count <= 8 && $0.utf8.allSatisfy { (48...57).contains($0) } && Int($0) != nil }
    }
    static func isNewer(_ remote: String, than current: String) -> Bool {
        guard validVersion(remote), validVersion(current) else { return false }
        let a = remote.split(separator: ".").compactMap { Int($0) }, b = current.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
enum LeftDeskVersion {}
