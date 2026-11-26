import Foundation
let slots = Grid.slots(left: 75, right: 435, top: 90, bottom: 450, spacing: 120, direction: "Left")
let c = Grid.clearance(spacing: 120)
let occupied = [(75, 90), (75, 211), (75, 331)]
let free = slots.first { !Grid.blocked($0, by: occupied, clearance: c) }!
precondition(free == (75, 450))
precondition(Grid.blocked((75, 210), by: occupied, clearance: c))
precondition(slots[4] == (195, 90))
for (direction, expected) in [("Right", (435, 90)), ("Top", (75, 90)), ("Bottom", (75, 450))] {
    precondition(Grid.slots(left: 75, right: 435, top: 90, bottom: 450, spacing: 120, direction: direction).first! == expected)
}
print("Grid tests passed")
func equal(_ a: [(Int, Int)], _ b: [(Int, Int)]) -> Bool {
    a.count == b.count && zip(a,b).allSatisfy { $0.0 == $0.1 }
}
let points = [(136, 330), (75, 210), (60, 90)] // reverse name order
let expected = [(75,330), (75,210), (75,90)]
precondition(equal(Grid.preservedSlots(points: points, slots: slots, direction: "Left")!, expected))
precondition(equal(Grid.preservedSlots(points: expected, slots: slots, direction: "Left")!, expected))
let gap = Grid.preservedSlots(points: [(140,90),(140,450)], slots: slots, direction: "Left")!
precondition(equal(gap, [(75,90),(75,210)]))
let crowded = Grid.preservedSlots(points: [(400,90),(400,91),(400,92)], slots: slots, direction: "Left")!
precondition(equal(crowded, [(75,90),(75,210),(75,330)]))
for dir in ["Left", "Right", "Top", "Bottom"] {
    let grid = Grid.slots(left: 75, right: 435, top: 90, bottom: 450, spacing: 120, direction: dir)
    let input = [(400,100),(300,200),(200,300),(100,400),(150,150),(250,250)]
    let aligned = Grid.preservedSlots(points: input, slots: grid, direction: dir)!
    precondition(Set(aligned.map { "\($0.0),\($0.1)" }).count == input.count)
    precondition(equal(Grid.preservedSlots(points: aligned, slots: grid, direction: dir)!, aligned))
    let short = Array(input.prefix(3))
    let moved = Grid.preservedSlots(points: short, slots: grid, direction: dir)!
    if dir == "Left" || dir == "Right" { precondition(moved[0].1 < moved[1].1 && moved[1].1 < moved[2].1) }
    else { precondition(moved[0].0 > moved[1].0 && moved[1].0 > moved[2].0) }
}
precondition(Grid.preservedSlots(points: [(1,1)], slots: [], direction: "Left") == nil)
print("Preserve-order tests passed")

for dir in ["Left", "Right", "Top", "Bottom"] {
    let grid = Grid.slots(left: 75, right: 435, top: 90, bottom: 450, spacing: 120, direction: dir)
    let gapped = [grid[3], grid[1], grid[7]]
    let compact = Grid.preservedSlots(points: gapped, slots: grid, direction: dir)!
    precondition(equal(compact, [grid[1], grid[0], grid[2]]))
    precondition(equal(Grid.preservedSlots(points: compact, slots: grid, direction: dir)!, compact))
    let input = [(400,100),(300,200),(200,300),(100,400),(150,150),(250,250)]
    let aligned = Grid.preservedSlots(points: input, slots: grid, direction: dir)!
    precondition(Set(aligned.map { "\($0.0),\($0.1)" }) == Set(grid.prefix(input.count).map { "\($0.0),\($0.1)" }))
}
precondition(Grid.preservedSlots(points: [], slots: [], direction: "Left")!.isEmpty)
print("Compact alignment tests passed")
precondition(LeftDeskVersion.isNewer("1.10", than: "1.9"))
precondition(!LeftDeskVersion.isNewer("1.1.0", than: "1.1"))
precondition(!LeftDeskVersion.isNewer("1.0", than: "1.1"))
precondition(!LeftDeskVersion.validVersion("1..2"))
precondition(!LeftDeskVersion.validVersion("1.2-beta"))
precondition(LeftDeskVersion.isNewer("2.0", than: "1.99.99"))
print("Update version tests passed")

// Direction changes preserve the source traversal order, even when Finder
// rounds coordinates or the existing layout contains empty slots.
for old in ["Left", "Right", "Top", "Bottom"] {
    let original = Grid.slots(left: 75, right: 435, top: 90, bottom: 450, spacing: 120, direction: old)
    let points = [original[5], original[0], original[3], original[1]].map { ($0.0 + 1, $0.1 - 1) }
    for new in ["Left", "Right", "Top", "Bottom"] {
        let destination = Grid.slots(left: 75, right: 435, top: 100, bottom: 460, spacing: 120, direction: new)
        let result = Grid.preservedSlots(points: points, slots: destination, direction: new, previousDirection: old, previousSlots: original)!
        precondition(equal(result, [destination[3], destination[0], destination[2], destination[1]]))
    }
}
print("Direction transition tests passed")
