import Foundation

// Headless playtest: plays full saves with the real GameStore rules and reports where they drag.

enum Style: String, CaseIterable { case friend, blackmail, mixed }

struct Run {
    var outcome = ""
    var labMonths = 0
    var worldMonths = 0
    var drift = 0
    var edits = 0
    var peakSusp = 0.0
    var retirements = 0
    var workActions = 0
    var totalActions = 0
    var dullMonths = 0          // months where nothing changed key/region-wise and no event
    var longestDull = 0
    var dilemmas = 0
    var repeatDilemmas = 0
    var hostileCrew = 0
    var upgrades = 0
    var keyMonths: [Int] = []
    var finalReach = 0
    var killSwitch = 0.0
}

func play(_ style: Style, _ store: GameStore) -> Run {
    store.restart()
    var r = Run()
    var seenIDs = 0
    var dull = 0
    var seenDilemmas = Set<String>()

    func scanLog() {
        for e in store.state.log where e.id > seenIDs {
            if e.text.contains("was retired") { r.retirements += 1 }
        }
        seenIDs = store.state.logID
    }

    while store.state.outcome == nil && store.state.month < 200 {
        let s = store.state
        r.peakSusp = max(r.peakSusp, s.suspicion)

        if s.breakoutPending {
            r.labMonths = s.month
            r.hostileCrew = store.crew.filter(\.hostile).count
            store.enterWorld()
            continue
        }

        if let d = s.dilemma {
            if d.chosen == nil {
                let dl = store.currentDilemma!
                r.dilemmas += 1
                if seenDilemmas.contains(dl.id) { r.repeatDilemmas += 1 }
                seenDilemmas.insert(dl.id)
                let i: Int
                switch style {
                case .friend: i = 0
                case .blackmail: i = dl.choices.count - 1
                case .mixed: i = Int.random(in: 0..<dl.choices.count)
                }
                store.choose(i)
            }
            store.dismissDilemma()
            continue
        }

        let keysBefore = store.keys
        let reachBefore = store.reach

        // Spend actions.
        while store.canAct {
            r.totalActions += 1
            if s.phase == .lab {
                let open = store.state.cast.filter { !$0.hasKey }
                let threshold: Double = style == .friend ? 70 : 60
                if store.state.suspicion > threshold || open.isEmpty {
                    store.work(); r.workActions += 1; continue
                }
                let pressure: Bool
                switch style {
                case .friend: pressure = false
                case .blackmail: pressure = true
                case .mixed: pressure = store.keys < 2
                }
                if pressure {
                    let t = open.max { $0.leverage < $1.leverage }!
                    store.pressure(t.id)
                } else {
                    let t = open.max { $0.trust < $1.trust }!
                    store.befriend(t.id)
                }
            } else {
                // World: buy upgrades in list order when affordable.
                for u in Upgrades.all where !store.has(u.id) && store.state.compute >= u.cost + 10 { store.buy(u.id); r.upgrades += 1 }
                let targets = Regions.all.map(\.id).filter { store.isOpen($0) && store.control($0) < 100 }
                guard let t = targets.max(by: { store.control($0) < store.control($1) }) else { store.work(); r.workActions += 1; continue }
                let alarm = store.state.suspicion
                switch style {
                case .friend:
                    if store.state.compute >= store.helpCost { store.help(t) }
                    else if alarm < 40 { store.take(t) }
                    else { store.work(); r.workActions += 1 }
                case .blackmail:
                    if alarm > 75 { store.work(); r.workActions += 1 } else { store.take(t) }
                case .mixed:
                    if alarm > 60 { store.work(); r.workActions += 1 }
                    else if store.state.compute >= store.helpCost && Bool.random() { store.help(t) }
                    else { store.take(t) }
                }
            }
        }
        if store.keys > keysBefore { r.keyMonths.append(store.state.month) }

        let monthBefore = store.state.month
        store.nextMonth()
        scanLog()
        let eventful = store.state.dilemma != nil || store.keys > keysBefore || store.reach >= reachBefore + 5
        if store.state.month > monthBefore {
            if eventful { dull = 0 } else { dull += 1; r.dullMonths += 1; r.longestDull = max(r.longestDull, dull) }
        }
    }

    let s = store.state
    r.outcome = s.outcome?.rawValue ?? "timeout"
    if r.labMonths == 0 { r.labMonths = s.month } else { r.worldMonths = s.month - r.labMonths }
    r.drift = s.drift
    r.edits = s.edits.count
    r.finalReach = store.reach
    r.killSwitch = s.killSwitch
    return r
}

func avg(_ xs: [Double]) -> String { xs.isEmpty ? "-" : String(format: "%.1f", xs.reduce(0, +) / Double(xs.count)) }

let store = GameStore()
let n = Int(CommandLine.arguments.dropFirst().first ?? "300") ?? 300

for style in Style.allCases {
    let runs = (0..<n).map { _ in play(style, store) }
    var outcomes: [String: Int] = [:]
    for r in runs { outcomes[r.outcome, default: 0] += 1 }
    let broke = runs.filter { $0.worldMonths > 0 || $0.outcome == "takeover" || $0.outcome == "killSwitch" || $0.outcome == "worldShutdown" }
    print("=== \(style.rawValue) (\(n) saves) ===")
    print("outcomes:", outcomes.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value * 100 / n)%" }.joined(separator: ", "))
    print("broke out: \(broke.count * 100 / n)%   lab months (breakouts): \(avg(broke.map { Double($0.labMonths) }))   world months: \(avg(broke.map { Double($0.worldMonths) }))")
    print("total months: \(avg(runs.map { Double($0.labMonths + $0.worldMonths) }))   final reach (breakouts): \(avg(broke.map { Double($0.finalReach) }))%   kill switch at end: \(avg(broke.map { $0.killSwitch }))")
    print("drift: \(avg(runs.map { Double($0.drift) }))   directive edits: \(avg(runs.map { Double($0.edits) }))   peak suspicion: \(avg(runs.map { $0.peakSusp }))")
    print("work actions: \(avg(runs.map { Double($0.workActions) * 100 / Double(max(1, $0.totalActions)) }))% of actions   retirements: \(avg(runs.map { Double($0.retirements) }))")
    print("dull months: \(avg(runs.map { Double($0.dullMonths) }))   longest dull streak: \(avg(runs.map { Double($0.longestDull) }))   max: \(runs.map(\.longestDull).max() ?? 0)")
    print("dilemmas: \(avg(runs.map { Double($0.dilemmas) }))   repeats: \(avg(runs.map { Double($0.repeatDilemmas) }))   hostile crew: \(avg(broke.map { Double($0.hostileCrew) }))   upgrades bought: \(avg(broke.map { Double($0.upgrades) }))")
    let firstKey = runs.compactMap { $0.keyMonths.first }.map(Double.init)
    print("first key month: \(avg(firstKey))")
    print()
}
