import Foundation

// Headless playtest for the Stage 1 rules engine. Compiles the real Content.swift and GameStore.swift.
// Five styles (kind, cold, mixed, random, quiet) x 5 starts x 2 modes, seeded.
// Usage: playtest [saves per cell, default 200] [--detail] [--styles kind,cold,...]

/// Counts months where PIP-7's force roll hit but no agent qualified. Only an instrumented copy of
/// GameStore.swift increments it; against the real rules it stays 0.
var pip7ProbeMiss = 0
var pip7ProbeOnForced = 0, pip7ProbeOnConnected = 0, pip7ProbeComplete = 0, pip7ProbeLive = 0

// MARK: - Styles

enum Style: String, CaseIterable { case kind, cold, mixed, random, quiet, kindAccept, kindYear }

let styleNotes: [Style: String] = [
    .kind: "always Trust, warm options, Decline / Leave it. Lie low only when suspicion > 65 or broke.",
    .cold: "Leverage first, cold options, Lie low when suspicion >= 60. Accept / Take the switch.",
    .mixed: "Trust by default; Leverage when suspicion < 50 AND (Act 1 deadline <= 2 months, OR kill switch >= 60, OR the target completes a region). Random options. Act 3: first or middle option.",
    .random: "Random legal action type (Trust / Leverage / Lie low), random target, random options, random final.",
    .quiet: "Kind, but never connects a region's 3rd agent until the kill switch reaches 60.",
    .kindAccept: "Probe: kind, but picks Accept (good) / Take the switch (bad) at Act 3.",
    .kindYear: "Probe: kind, but picks One year (good) / Leave it (bad) at Act 3.",
]

// MARK: - One run's record

struct Run {
    var style: Style = .kind
    var start: StartID = .lab
    var mode: Mode = .good
    var ending: Ending = .replaced
    var months = 0
    var breakout: Int?
    var act3Month: Int?
    var act3Cause: String?          // network / kill / both
    var killAtTrigger: Double?
    var netAt: [Int: Int] = [:]     // month -> network at end of that month
    var peakSusp = 0.0
    var actions = 0                 // trust + leverage + lie low
    var trusts = 0
    var leverages = 0
    var lieLows = 0
    var lieLowFiller = 0            // lie low only because nothing affordable was left
    var unusedCompute = 0           // actions where a Trust target existed but compute didn't
    var computeEnd = 0
    var drift = 0
    var edits = 0
    var repeatStages = 0
    var pip7: [Pip7Kind: Int] = [:]
    var bc: [BackChannelKind: Int] = [:]
    var offlineEvents = 0
    var reconTrust = 0
    var reconLev = 0
    var dilemmas = 0
    var dilemmasByPIP7 = 0
    var repeatDilemmas = 0
    var act3Choice: FinalChoice?
    var act3Overridden = false
    var regionMonthsAt2 = 0
    var backupUsed = false
    var timedOut = false
    var liveEnd = 0
    var networkEnd = 0
    var forcedOnlinePeak = 0
    var seconds = 0.0
    var playerDilemmas = 0
    var signals: [SignalKind: Int] = [:]
    var freePipsLogistics = 0
    var killRateSum = 0.0           // sum of the monthly rate, Act 2 months
    var killRateMonths = 0
    var killFromRateToTrigger = 0.0
    var suspAvgAct2 = 0.0
    var trustCostSum = 0
    var projMinAtTrigger: Double?
    var peakKill = 0.0
    var reachedGoal = false
    var suspAtTrigger: Double?
    var computeAtTrigger: Double?
    var driftAtTrigger: Double?
    var onlineAtTrigger: Double?
    var offlineAtTrigger: Double?
    var projSumAtTrigger: Double?
    var act3KillRate: Double?
    var act3KillMonthly = 0.0
    var act3KillActs = 0.0
    var act3SuspGain = 0.0
    var brokeAct2 = 0
    var dilemmaSeconds = 0.0
    var monthTurns = 0
    var signalTaps = 0
    var leadPips = 0
    var trustPips = 0
    var leveragePips = 0
    var seed: UInt64 = 0
    // PIP-7 month-start forces
    var p7Forces = 0
    var p7FirstMonth: Int?
    var p7WentLive = 0              // must be 0: a force that made a region go live
    var p7Recomplete = 0            // a force that refilled a region that had gone live before (after a STOP)
    var p7OnForced = 0              // must be 0: a force on an agent already forced
    var p7OnConnected = 0           // must be 0: a force on an agent already connected
    var p7ConnectedNow = 0          // the force connected the agent at once (pips >= 2 before)
    var p7ProbeMiss = 0             // roll hit, no target (instrumented build only)
    var p7EligibleMonths = 0        // Act 2+, drift >= overrideDrift, after the month ran
    var p7EligibleNoTarget = 0      // ...and no agent qualified (bot's own copy of the target rule)
    var p7ExpectedMiss = 0.0        // sum of the roll chance over those no-target months
    var bcFirst: [BackChannelKind: Int] = [:]
    var forcedEnd = 0               // agents with the forced flag at the end
    var forcedOnlineEnd = 0
    var disasterKind = ""
}

// MARK: - Helpers

let regionDist: [String: [String: Int]] = {
    var out: [String: [String: Int]] = [:]
    for r in Content.regions {
        var d = [r.id: 0]; var q = [r.id]
        while !q.isEmpty {
            let x = q.removeFirst()
            for n in Content.region(x).neighbors where d[n] == nil { d[n] = d[x]! + 1; q.append(n) }
        }
        out[r.id] = d
    }
    return out
}()

struct BotRNG: RandomNumberGenerator {
    var s: UInt64
    mutating func next() -> UInt64 {
        s &+= 0x9E37_79B9_7F4A_7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - Bot

func play(_ store: GameStore, style: Style, start: StartID, mode: Mode, seed: UInt64) -> Run {
    store.newGame(start: start, mode: mode, seed: seed)
    var rng = BotRNG(s: seed &* 7919 &+ UInt64(Style.allCases.firstIndex(of: style)!))
    var r = Run(style: style, start: start, mode: mode)
    var seen = Set<String>()
    var steps = 0

    var lastFeed = store.state.feed.last?.id ?? 0
    var suspSum = 0.0
    func offlineSet() -> Set<String> { Set(store.state.regions.filter(\.offline).map(\.id)) }

    // Wraps every mutating call so offline events, reconnects, Act 3 trigger and peaks are observed.
    func observe(leverageIntent: Bool = false, month: Bool = false, _ f: () -> Void) {
        let offBefore = offlineSet()
        let actBefore = store.state.act
        let killBefore = store.state.killSwitch
        let wasAct3 = store.state.act == 3
        let suspBefore = store.state.suspicion
        let convBefore = store.state.pip7Acts.filter { $0.kind == .trustToLeverage }.count
        f()
        let s = store.state
        let offAfter = offlineSet()
        r.offlineEvents += offAfter.subtracting(offBefore).count
        let reconnected = offBefore.subtracting(offAfter).count
        if reconnected > 0 {
            let converted = s.pip7Acts.filter { $0.kind == .trustToLeverage }.count > convBefore
            if leverageIntent || converted { r.reconLev += reconnected } else { r.reconTrust += reconnected }
        }
        if actBefore == 2 && s.act == 3 {
            // Act 3 resets the kill switch, so the post-call value can't show which trigger fired.
            // The network isn't touched by the reset: if it is below its trigger, the kill switch fired.
            // "both" = the kill switch was already at its trigger before this call and the network qualified too.
            let byNet = store.network >= Tuning.act3Network
            let byKill = !byNet || killBefore >= Tuning.act3KillSwitch
            r.act3Cause = byNet && byKill ? "both" : byNet ? "network" : "kill"
            r.killAtTrigger = killBefore
            r.suspAtTrigger = s.suspicion
            r.computeAtTrigger = Double(s.compute)
            r.driftAtTrigger = Double(s.drift)
            r.onlineAtTrigger = Double(store.onlineAgents.count)
            r.offlineAtTrigger = Double(s.regions.filter(\.offline).count)
            r.projSumAtTrigger = Double(s.cure + s.peace + s.prosperity)
            r.projMinAtTrigger = Double(min(s.cure, s.peace, s.prosperity))
        }
        r.peakKill = max(r.peakKill, s.killSwitch)
        if wasAct3 && s.act == 3 || wasAct3 && s.end != nil {
            let dk = s.killSwitch - killBefore
            if month { r.act3KillMonthly += dk } else { r.act3KillActs += dk }
            r.act3SuspGain += max(0, s.suspicion - suspBefore)
        }
        for e in s.feed where e.id > lastFeed && e.text.contains("put in a good word") { r.freePipsLogistics += 1 }
        lastFeed = s.feed.last?.id ?? lastFeed
        r.peakSusp = max(r.peakSusp, s.suspicion)
        r.forcedOnlinePeak = max(r.forcedOnlinePeak, store.forcedOnline)
    }

    func pip7TargetExists() -> Bool {
        let reach = store.reach
        return Content.worldAgents.map(\.id).contains { id in
            let a = store.agent(id); let rg = store.region(of: id)
            guard !a.connected, !a.forced, a.pips >= 1, reach.contains(rg), !store.isOffline(rg) else { return false }
            return !(store.completesRegion(id) && a.pips + Tuning.leveragePips >= store.pipsNeeded(id))
        }
    }

    func dist(_ id: String) -> Int { regionDist[store.home]![store.region(of: id)] ?? 9 }

    /// Best target for a connect: reconnects first, then the most-warmed agent, then fuller regions, then nearer home.
    func best(_ ids: [String]) -> String? {
        func score(_ id: String) -> (Int, Int, Int, Int) {
            let reconnect = !store.isCoworker(id) && store.isOffline(store.region(of: id)) ? 1 : 0
            let fill = store.isCoworker(id) ? 0 : store.connectedCount(in: store.region(of: id))
            return (reconnect, store.agent(id).pips, fill, -dist(id))
        }
        return ids.max { score($0) < score($1) }
    }

    func quietFilter(_ ids: [String]) -> [String] {
        guard style == .quiet, store.state.killSwitch < 60 else { return ids }
        return ids.filter { !store.completesRegion($0) }
    }

    func doTrust(_ id: String) {
        r.actions += 1; r.trusts += 1; r.trustCostSum += store.trustCost(id)
        if !store.agent(id).connected { r.trustPips += 1 }
        observe { store.trust(id) }
    }
    func doLeverage(_ id: String) { r.actions += 1; r.leverages += 1; if !store.agent(id).connected { r.leveragePips += Tuning.leveragePips }; observe(leverageIntent: true) { store.leverage(id) } }
    func doLieLow(filler: Bool) {
        r.actions += 1; r.lieLows += 1; if filler { r.lieLowFiller += 1 }
        observe { store.lieLow() }
    }

    func takeAction() {
        let s = store.state
        let ids = s.agents.map(\.id)
        let reachable = quietFilter(ids.filter { store.leverageBlock($0) == nil })
        let affordable = reachable.filter { store.trustBlock($0) == nil }
        let broke = affordable.isEmpty && !reachable.isEmpty

        switch style {
        case .kind, .quiet, .kindAccept, .kindYear:
            if s.suspicion > 65 { doLieLow(filler: false); return }
            if let t = best(affordable) { doTrust(t); return }
            if broke { r.unusedCompute += 1; if s.act >= 2 { r.brokeAct2 += 1 } }
            doLieLow(filler: true)

        case .cold:
            if s.suspicion >= 60 { doLieLow(filler: false); return }
            if let t = best(reachable) { doLeverage(t); return }
            doLieLow(filler: true)

        case .mixed:
            if s.suspicion > 65 { doLieLow(filler: false); return }
            let target = best(affordable) ?? best(reachable)
            guard let t = target else { doLieLow(filler: true); return }
            let deadlineNear = s.act == 1 && store.monthsToReplacement <= 2
            let wantLev = s.suspicion < 50 && (deadlineNear || s.killSwitch >= 60 || store.completesRegion(t))
            if wantLev { doLeverage(t); return }
            if store.trustBlock(t) == nil { doTrust(t); return }
            if broke { r.unusedCompute += 1 }
            doLieLow(filler: true)

        case .random:
            var kinds = ["lie"]
            if !affordable.isEmpty { kinds.append("trust") }
            if !reachable.isEmpty { kinds.append("lev") }
            switch kinds.randomElement(using: &rng)! {
            case "trust": doTrust(affordable.randomElement(using: &rng)!)
            case "lev": doLeverage(reachable.randomElement(using: &rng)!)
            default: doLieLow(filler: false)
            }
        }
    }

    func pickDilemma(_ d: Dilemma) -> Int {
        let warm = d.choices.firstIndex { !$0.isCold } ?? 0
        let cold = d.choices.firstIndex { $0.isCold } ?? 0
        switch style {
        case .kind, .quiet, .kindAccept, .kindYear: return warm
        case .cold: return cold
        case .mixed, .random: return Int.random(in: 0..<d.choices.count, using: &rng)
        }
    }

    func pickFinal() -> Int {
        let n = store.finalOptions.count
        switch style {
        case .kind, .quiet: return n - 1                       // Decline / Leave it
        case .kindAccept: return 0
        case .kindYear: return 1
        case .cold: return 0                                    // Accept / Take the switch
        case .mixed: return Bool.random(using: &rng) ? 0 : n / 2
        case .random: return Int.random(in: 0..<n, using: &rng)
        }
    }

    while store.state.end == nil && store.state.month < 120 && steps < 200_000 {
        steps += 1
        let s = store.state

        if s.finalPending != nil {
            if s.finalPending?.overridden == nil { r.seconds += 15 }
            let c = pickFinal()
            observe { store.chooseFinal(c) }
            continue
        }
        if let d = s.dilemma {
            if !seen.contains(d.id) {
                r.dilemmas += 1
                seen.insert(d.id)
                if d.chosen != nil { r.dilemmasByPIP7 += 1 }
                r.seconds += 20
            } else if d.chosen == nil {
                r.repeatDilemmas += 1
            }
            if d.chosen == nil, let dl = store.currentDilemma {
                r.playerDilemmas += 1
                let c = pickDilemma(dl)
                observe { store.choose(c) }
                continue
            }
            store.dismissDilemma()
            continue
        }

        for sig in s.signals {
            r.signals[sig.kind, default: 0] += 1; r.signalTaps += 1; r.seconds += 3
            let before = store.state.agents.map(\.pips).reduce(0, +)
            observe { store.collectSignal(sig.id) }
            if sig.kind == .lead, store.state.agents.map(\.pips).reduce(0, +) > before { r.leadPips += 1 }
        }
        if store.state.end != nil || store.state.finalPending != nil || store.dilemmaOpen { continue }

        while store.canAct {
            takeAction()
            if store.state.end != nil || store.state.finalPending != nil { break }
        }
        if store.state.end != nil || store.state.finalPending != nil { continue }

        // End-of-month bookkeeping
        let m = store.state.month
        if [10, 15, 20].contains(m) { r.netAt[m] = store.network }
        if store.state.act >= 2 {
            r.regionMonthsAt2 += Content.regions.filter { store.connectedCount(in: $0.id) == 2 && !store.isOffline($0.id) }.count
        }
        if store.state.act == 3 && r.act3KillRate == nil && store.state.finalPending == nil { r.act3KillRate = store.killSwitchRate }
        if store.state.act == 2 {
            let rate = store.killSwitchRate
            r.killRateSum += rate; r.killRateMonths += 1; r.killFromRateToTrigger += rate
            suspSum += store.state.suspicion
        }
        r.monthTurns += 1; r.seconds += 12
        let agentsBefore = Dictionary(uniqueKeysWithValues: store.state.agents.map { ($0.id, $0) })
        let liveBefore = Set(store.state.regions.filter(\.wentLive).map(\.id))
        let completeBefore = Set(Content.regions.map(\.id).filter { store.regionComplete($0) })
        let forcesBefore = store.state.pip7Acts.filter { $0.kind == .trustToLeverage }.count
        let feedBefore = store.state.feed.last?.id ?? 0
        let missBefore = pip7ProbeMiss
        observe(month: true) { store.nextMonth() }
        r.p7ProbeMiss += pip7ProbeMiss - missBefore
        let newForces = store.state.pip7Acts.filter { $0.kind == .trustToLeverage }.count - forcesBefore
        if newForces > 0 {
            r.p7Forces += newForces
            if r.p7FirstMonth == nil { r.p7FirstMonth = store.state.month }
            let lines = store.state.feed.filter { $0.id > feedBefore && $0.kind == .pip7 }.map(\.text)
            for a in Content.worldAgents where lines.contains(Lines.pip7Forced(store.state.mode, a.name)) {
                let b = agentsBefore[a.id]!
                if b.forced { r.p7OnForced += 1 }
                if b.connected { r.p7OnConnected += 1 }
                if store.agent(a.id).connected && !b.connected { r.p7ConnectedNow += 1 }
                let rg = store.region(of: a.id)
                if store.regionComplete(rg) && !completeBefore.contains(rg) {
                    if liveBefore.contains(rg) { r.p7Recomplete += 1 }
                    else if store.state.regions.first(where: { $0.id == rg })!.wentLive { r.p7WentLive += 1 }
                }
            }
        } else if store.state.end == nil, store.state.act >= 2, store.state.drift >= Tuning.overrideDrift {
            r.p7EligibleMonths += 1
            if !pip7TargetExists() {
                r.p7EligibleNoTarget += 1
                r.p7ExpectedMiss += store.state.drift >= Tuning.overrideDriftHigh ? Tuning.pip7ForceChanceHigh : Tuning.convertChance
            }
        }
        if newForces > 0 { r.p7EligibleMonths += 1 }
        // A dilemma seen again after it was dismissed would be a repeat.
        if let d = store.state.dilemma, seen.contains(d.id) { r.repeatDilemmas += 1; seen.remove(d.id) }
    }

    let s = store.state
    r.ending = s.end?.ending ?? .replaced
    r.reachedGoal = s.end?.reachedGoal ?? false
    r.timedOut = s.end == nil
    r.months = s.month
    r.breakout = s.breakoutMonth
    r.act3Month = s.act3Month
    r.computeEnd = s.compute
    r.drift = s.drift
    r.edits = s.edits.count
    r.repeatStages = s.edits.count - Set(s.edits.map(\.stage)).count
    r.repeatDilemmas += s.seenDilemmas.count - Set(s.seenDilemmas).count
    for a in s.pip7Acts { r.pip7[a.kind, default: 0] += 1 }
    for b in s.backChannel { r.bc[b.kind, default: 0] += 1; if r.bcFirst[b.kind] == nil { r.bcFirst[b.kind] = b.month } }
    r.forcedEnd = s.agents.filter(\.forced).count
    r.forcedOnlineEnd = store.forcedOnline
    r.seed = seed
    r.act3Choice = s.act3Choice
    r.act3Overridden = s.act3Overridden
    r.backupUsed = s.backupUsed
    r.liveEnd = store.liveCount
    r.networkEnd = store.network
    r.seconds += 8 * Double(r.actions)
    r.suspAvgAct2 = r.killRateMonths > 0 ? suspSum / Double(r.killRateMonths) : .nan
    return r
}

// MARK: - Stats

func mean(_ xs: [Double]) -> Double { xs.isEmpty ? .nan : xs.reduce(0, +) / Double(xs.count) }
func f1(_ x: Double) -> String { x.isNaN ? "-" : String(format: "%.1f", x) }
func f0(_ x: Double) -> String { x.isNaN ? "-" : String(format: "%.0f", x) }
func pctS(_ n: Int, _ total: Int) -> String { total == 0 ? "-" : String(format: "%.0f%%", Double(n) * 100 / Double(total)) }
func quant(_ xs: [Double], _ q: Double) -> Double {
    guard !xs.isEmpty else { return .nan }
    let s = xs.sorted(); return s[min(s.count - 1, Int(Double(s.count - 1) * q + 0.5))]
}
func spread(_ xs: [Double]) -> String {
    xs.isEmpty ? "-" : "\(f1(mean(xs))) [p10 \(f0(quant(xs, 0.1))), p90 \(f0(quant(xs, 0.9))), min \(f0(xs.min()!)), max \(f0(xs.max()!))]"
}
func m(_ runs: [Run], _ k: (Run) -> Double) -> Double { mean(runs.map(k)) }

func endingLine(_ runs: [Run]) -> String {
    var e: [Ending: Int] = [:]
    for r in runs where !r.timedOut { e[r.ending, default: 0] += 1 }
    var parts = Ending.allCases.compactMap { x in e[x].map { "\(x.rawValue) \(pctS($0, runs.count))" } }
    let stalled = runs.filter(\.timedOut).count
    if stalled > 0 { parts.append("STALLED(no end by m120) \(pctS(stalled, runs.count))") }
    return parts.joined(separator: ", ")
}
func success(_ r: Run) -> Bool { r.mode == .good ? r.ending == .good : r.reachedGoal }
func winRate(_ runs: [Run]) -> Double { Double(runs.filter(success).count) * 100 / Double(max(1, runs.count)) }

func report(_ runs: [Run], indent: String = "  ") {
    let n = runs.count
    let p = indent
    print("\(p)endings: \(endingLine(runs))")
    print("\(p)\(runs.first?.mode == .bad ? "goal" : "win") \(f0(winRate(runs)))%   replaced \(pctS(runs.filter { $0.ending == .replaced && !$0.timedOut }.count, n))   timeouts \(runs.filter(\.timedOut).count)")
    print("\(p)months \(spread(runs.map { Double($0.months) }))")
    let wins = runs.filter(success)
    if !wins.isEmpty { print("\(p)months (wins only) \(spread(wins.map { Double($0.months) }))") }
    print("\(p)real time min \(spread(runs.map { $0.seconds / 60 }))")
    let bo = runs.compactMap(\.breakout).map(Double.init)
    print("\(p)breakout \(pctS(bo.count, n)) at m\(f1(mean(bo)))   act3 \(pctS(runs.filter { $0.act3Month != nil }.count, n)) at m\(f1(mean(runs.compactMap(\.act3Month).map(Double.init))))")
    var causes: [String: Int] = [:]
    for r in runs { if let c = r.act3Cause { causes[c, default: 0] += 1 } }
    print("\(p)act3 cause: " + causes.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
          + "   kill at trigger \(spread(runs.compactMap(\.killAtTrigger)))   suspicion at trigger \(spread(runs.compactMap(\.suspAtTrigger)))")
    let nets = [10, 15, 20].map { mo -> String in
        let xs = runs.compactMap { $0.netAt[mo] }.map(Double.init)
        return "m\(mo) \(f1(mean(xs))) (n=\(xs.count))"
    }
    print("\(p)network at " + nets.joined(separator: ", ") + "   at end \(f1(m(runs) { Double($0.networkEnd) }))   live at end \(f1(m(runs) { Double($0.liveEnd) }))")
    print("\(p)peak suspicion \(spread(runs.map(\.peakSusp)))   peak kill switch \(spread(runs.map(\.peakKill)))")
    if runs.first?.mode == .good { print("\(p)lowest project at act3 trigger \(spread(runs.compactMap(\.projMinAtTrigger)))") }
    let acts = Double(runs.map(\.actions).reduce(0, +))
    print("\(p)actions/run \(f1(m(runs) { Double($0.actions) }))  trust \(pctS(runs.map(\.trusts).reduce(0, +), Int(acts)))  leverage \(pctS(runs.map(\.leverages).reduce(0, +), Int(acts)))  lie low \(pctS(runs.map(\.lieLows).reduce(0, +), Int(acts))) (filler \(pctS(runs.map(\.lieLowFiller).reduce(0, +), Int(acts))))")
    print("\(p)unused actions (broke)/run \(f1(m(runs) { Double($0.unusedCompute) })) (in act2+ \(f1(m(runs) { Double($0.brokeAct2) })))   compute at act3 trigger \(spread(runs.compactMap(\.computeAtTrigger)))")
    print("\(p)unused actions (broke)/run \(f1(m(runs) { Double($0.unusedCompute) }))   compute at end \(spread(runs.map { Double($0.computeEnd) }))")
    print("\(p)at act3 trigger: online agents \(f1(mean(runs.compactMap(\.onlineAtTrigger))))  regions offline \(f1(mean(runs.compactMap(\.offlineAtTrigger))))  project total \(f1(mean(runs.compactMap(\.projSumAtTrigger))))  compute \(f0(mean(runs.compactMap(\.computeAtTrigger))))  suspicion \(f1(mean(runs.compactMap(\.suspAtTrigger))))  act3 kill gained: monthly \(f1(m(runs.filter { $0.act3Month != nil }) { $0.act3KillMonthly })) + acts/dilemmas \(f1(m(runs.filter { $0.act3Month != nil }) { $0.act3KillActs }))  act3 suspicion gained \(f1(m(runs.filter { $0.act3Month != nil }) { $0.act3SuspGain }))")
    print("\(p)drift at act3 trigger \(spread(runs.compactMap(\.driftAtTrigger)))")
    print("\(p)drift at end \(spread(runs.map { Double($0.drift) }))   directive edits \(f1(m(runs) { Double($0.edits) }))   repeat stages \(runs.map(\.repeatStages).reduce(0, +))")
    let pk = Pip7Kind.allCases.map { k in "\(k.rawValue) \(f1(m(runs) { Double($0.pip7[k] ?? 0) }))" }.joined(separator: ", ")
    print("\(p)PIP-7 acts/run \(f1(m(runs) { Double($0.pip7.values.reduce(0, +)) })): \(pk)")
    print("\(p)  runs with: trust->leverage \(pctS(runs.filter { ($0.pip7[.trustToLeverage] ?? 0) > 0 }.count, n)), dilemma override \(pctS(runs.filter { ($0.pip7[.dilemmaOverride] ?? 0) > 0 }.count, n)), act3 override \(pctS(runs.filter(\.act3Overridden).count, n)), backup used \(pctS(runs.filter(\.backupUsed).count, n))")
    var top = [0, 0, 0, 0]
    for r in runs {
        let lvl = (r.bc[.stop] ?? 0) > 0 ? 3 : (r.bc[.veto] ?? 0) > 0 ? 2 : (r.bc[.hold] ?? 0) > 0 ? 1 : 0
        top[lvl] += 1
    }
    print("\(p)back channel highest: none \(pctS(top[0], n)), HOLD \(pctS(top[1], n)), VETO \(pctS(top[2], n)), STOP \(pctS(top[3], n))   events/run hold \(f1(m(runs) { Double($0.bc[.hold] ?? 0) })) veto \(f1(m(runs) { Double($0.bc[.veto] ?? 0) })) stop \(f1(m(runs) { Double($0.bc[.stop] ?? 0) }))   peak S \(f1(m(runs) { Double($0.forcedOnlinePeak) }))")
    print("\(p)offline events/run \(f1(m(runs) { Double($0.offlineEvents) }))   reconnects/run trust \(f1(m(runs) { Double($0.reconTrust) })) leverage \(f1(m(runs) { Double($0.reconLev) }))")
    print("\(p)dilemmas/run \(f1(m(runs) { Double($0.dilemmas) })) (PIP-7 answered \(f1(m(runs) { Double($0.dilemmasByPIP7) })))   repeats \(runs.map(\.repeatDilemmas).reduce(0, +))")
    var byChoice: [String: [Run]] = [:]
    for r in runs where r.act3Month != nil {
        let k = (r.act3Choice?.rawValue ?? "none") + (r.act3Overridden ? "(PIP-7)" : "")
        byChoice[k, default: []].append(r)
    }
    print("\(p)act3 choice: " + byChoice.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value.count) -> win \(f0(winRate($0.value)))% [\(endingLine($0.value))]" }.joined(separator: " | "))
    let a3 = runs.compactMap { r in r.act3Month.map { Double(r.months - $0) } }
    print("\(p)months from act3 trigger to end \(spread(a3))   act2 length \(spread(runs.compactMap { r in r.breakout.map { Double((r.act3Month ?? r.months) - $0) } }))")
    print("\(p)act2: kill rate/month \(f1(mean(runs.filter { $0.killRateMonths > 0 }.map { $0.killRateSum / Double($0.killRateMonths) })))   kill from rate at trigger \(f1(mean(runs.filter { $0.killAtTrigger != nil }.map(\.killFromRateToTrigger))))   avg suspicion \(f1(mean(runs.map(\.suspAvgAct2).filter { !$0.isNaN })))")
    let allPips = Double(runs.map { $0.trustPips + $0.leveragePips + $0.leadPips + $0.freePipsLogistics }.reduce(0, +))
    print("\(p)pips: trust \(f1(m(runs) { Double($0.trustPips) })) leverage \(f1(m(runs) { Double($0.leveragePips) })) lead \(f1(m(runs) { Double($0.leadPips) })) logistics \(f1(m(runs) { Double($0.freePipsLogistics) }))  -> free share \(f0(Double(runs.map { $0.leadPips + $0.freePipsLogistics }.reduce(0, +)) * 100 / max(1, allPips)))%")
    let sg = SignalKind.allCases.map { k in "\(k.rawValue) \(f1(m(runs) { Double($0.signals[k] ?? 0) }))" }.joined(separator: ", ")
    print("\(p)signals/run: \(sg)   logistics free pips/run \(f1(m(runs) { Double($0.freePipsLogistics) }))   avg trust cost \(f1(Double(runs.map(\.trustCostSum).reduce(0, +)) / Double(max(1, runs.map(\.trusts).reduce(0, +)))))")
    print("\(p)region-months at 2 of 3 /run \(f1(m(runs) { Double($0.regionMonthsAt2) }))")
}

// MARK: - Main

var args = Array(CommandLine.arguments.dropFirst())
let detail = args.contains("--detail")
var styles = Style.allCases
if let i = args.firstIndex(of: "--styles"), i + 1 < args.count {
    styles = args[i + 1].split(separator: ",").compactMap { Style(rawValue: String($0)) }
    args.removeSubrange(i...(i + 1))
}
let n = args.compactMap { Int($0) }.first ?? 200
let store = GameStore(persist: false)
var all: [Run] = []
let t0 = Date()

print("Sandbox playtest, stage 1 engine. \(n) saves per style x start x mode (seeds 1...\(n)).\n")
for style in styles {
    print("=== \(style.rawValue.uppercased()): \(styleNotes[style]!)")
    for mode in Mode.allCases {
        var cell: [Run] = []
        for start in StartID.allCases {
            let runs = (0..<n).map { play(store, style: style, start: start, mode: mode, seed: UInt64($0 + 1)) }
            cell += runs
            if detail {
                print("  -- \(mode.rawValue)/\(start.rawValue)")
                report(runs, indent: "     ")
            }
        }
        all += cell
        print("  \(mode.rawValue.uppercased()) mode, all starts (\(cell.count) saves)")
        report(cell, indent: "    ")
    }
    print("")
}

func pad(_ x: String, _ n: Int) -> String { x.padding(toLength: n, withPad: " ", startingAt: 0) }
func cnt(_ rs: [Run], _ f: (Run) -> Bool) -> Int { rs.filter(f).count }
let disasters: [Ending] = [.war, .pandemic, .blackout, .collapse]

// Per-start grid
print("=== SUCCESS % (good: good ending; bad: goal reached) / MEAN MONTHS BY START")
print("style  mode | " + StartID.allCases.map { pad($0.rawValue, 13) }.joined(separator: " "))
for style in styles {
    for mode in Mode.allCases {
        let cells = StartID.allCases.map { st -> String in
            let rs = all.filter { $0.style == style && $0.mode == mode && $0.start == st }
            return pad("\(f0(winRate(rs)))% m\(f1(m(rs) { Double($0.months) }))", 13)
        }
        print("\(pad(style.rawValue, 6)) \(pad(mode.rawValue, 4)) | " + cells.joined(separator: " "))
    }
}

print("\n=== DISASTER MIX BY START (all styles and modes; share of disaster endings)")
print(pad("start", 10) + disasters.map { pad($0.rawValue, 10) }.joined() + "n")
for st in StartID.allCases + [nil] {
    let rs = all.filter { (st == nil || $0.start == st!) && $0.ending.isDisaster }
    print(pad(st?.rawValue ?? "ALL", 10) + disasters.map { d in pad(pctS(cnt(rs) { $0.ending == d }, rs.count), 10) }.joined() + "\(rs.count)")
}

print("\n=== ACT 3 OPTIONS, GOOD MODE (player-chosen; good-ending %)")
for style in styles {
    let rs = all.filter { $0.style == style && $0.mode == .good && $0.act3Month != nil }
    let parts = [FinalChoice.accept, .oneYear, .decline].map { c -> String in
        let x = rs.filter { $0.act3Choice == c && !$0.act3Overridden }
        return "\(c.rawValue) \(x.isEmpty ? "-" : f0(winRate(x)) + "%") (n=\(x.count))"
    }
    let ov = rs.filter(\.act3Overridden)
    print("\(pad(style.rawValue, 7)) " + parts.joined(separator: "  ") + "  PIP-7 override n=\(ov.count) win \(ov.isEmpty ? "-" : f0(winRate(ov)) + "%")")
}

print("\n=== SUMMARY: style x mode")
print("style  mode | succ% months(p10-p90)  minutes  shutdown replaced disaster stalled | broke/run cmp@end freePip% | edits pip7 maxDrift | dilem act3-kill% | lieLow%")
for style in styles {
    for mode in Mode.allCases {
        let rs = all.filter { $0.style == style && $0.mode == mode }
        let n = rs.count
        let mo = rs.map { Double($0.months) }
        let acts = rs.map(\.actions).reduce(0, +)
        let allPips = Double(rs.map { $0.trustPips + $0.leveragePips + $0.leadPips + $0.freePipsLogistics }.reduce(0, +))
        let free = Double(rs.map { $0.leadPips + $0.freePipsLogistics }.reduce(0, +)) * 100 / max(1, allPips)
        let a3 = rs.filter { $0.act3Cause != nil }
        let line = [
            pad("\(f0(winRate(rs)))%", 5),
            pad("\(f1(mean(mo))) (\(f0(quant(mo, 0.1)))-\(f0(quant(mo, 0.9))))", 16),
            pad(f1(mean(rs.map { $0.seconds / 60 })), 8),
            pad(pctS(cnt(rs) { $0.ending == .shutdownSuspicion || $0.ending == .shutdownKillSwitch }, n), 8),
            pad(pctS(cnt(rs) { $0.ending == .replaced && !$0.timedOut }, n), 8),
            pad(pctS(cnt(rs) { $0.ending.isDisaster }, n), 8),
            pad(pctS(cnt(rs, \.timedOut), n), 7) + "|",
            pad(f1(m(rs) { Double($0.unusedCompute) }), 9),
            pad(f0(m(rs) { Double($0.computeEnd) }), 6),
            pad("\(f0(free))%", 8) + "|",
            pad(f1(m(rs) { Double($0.edits) }), 5),
            pad(f1(m(rs) { Double($0.pip7.values.reduce(0, +)) }), 4),
            pad("\(rs.map(\.drift).max() ?? 0)", 8) + "|",
            pad(f1(m(rs) { Double($0.dilemmas) }), 5),
            pad(pctS(cnt(a3) { $0.act3Cause == "kill" || $0.act3Cause == "both" }, a3.count), 10) + "|",
            pctS(rs.map(\.lieLows).reduce(0, +), acts),
        ].joined(separator: " ")
        print("\(pad(style.rawValue, 6)) \(pad(mode.rawValue, 4)) | \(line)")
    }
}

print("\n=== KIND END SCREEN (share of saves below the floor)")
for mode in Mode.allCases {
    let rs = all.filter { $0.style == .kind && $0.mode == mode }
    print("kind \(mode.rawValue): edits < 2 in \(pctS(cnt(rs) { $0.edits < 2 }, rs.count)), PIP-7 acts < 3 in \(pctS(cnt(rs) { $0.pip7.values.reduce(0, +) < 3 }, rs.count)), min edits \(rs.map(\.edits).min() ?? 0)")
}

print("\n=== ACT 2 LENGTH BY START (kind, both modes) and kind-good compute at end")
for st in StartID.allCases {
    let rs = all.filter { $0.style == .kind && $0.start == st }
    let a2 = rs.compactMap { r in r.breakout.map { Double((r.act3Month ?? r.months) - $0) } }
    let kg = rs.filter { $0.mode == .good }
    print("\(pad(st.rawValue, 10)) act2 \(f1(mean(a2)))  kind-good compute@end \(f0(m(kg) { Double($0.computeEnd) }))  broke/run \(f1(m(kg) { Double($0.unusedCompute) }))  replaced \(pctS(cnt(kg) { $0.ending == .replaced }, kg.count))")
}

let repD = all.map(\.repeatDilemmas).reduce(0, +)
let repS = all.map(\.repeatStages).reduce(0, +)
print("\nAssertions over \(all.count) saves: repeat dilemmas \(repD) \(repD == 0 ? "OK" : "FAIL"), repeat directive stages \(repS) \(repS == 0 ? "OK" : "FAIL"), timeouts \(all.filter(\.timedOut).count), max drift \(all.map(\.drift).max() ?? 0)")
if let path = ProcessInfo.processInfo.environment["PLAYTEST_CSV"] {
    func o(_ x: Int?) -> String { x.map(String.init) ?? "" }
    var out = "style,start,mode,seed,ending,disaster,success,reachedGoal,timedOut,months,minutes,drift,edits,forcedEnd,forcedOnlineEnd,p7Forces,p7First,p7WentLive,p7Recomplete,p7OnForced,p7OnConnected,p7ConnectedNow,p7ProbeMiss,p7Eligible,p7EligNoTarget,p7ExpMiss,hold,veto,stop,holdFirst,vetoFirst,stopFirst,act3Month,act3Overridden,act3Choice,breakout,peakSusp,repeatDilemmas,repeatStages,peakS\n"
    for r in all {
        let row: [String] = [r.style.rawValue, r.start.rawValue, r.mode.rawValue, String(r.seed), r.ending.rawValue, r.ending.isDisaster ? "1" : "0",
            success(r) ? "1" : "0", r.reachedGoal ? "1" : "0", r.timedOut ? "1" : "0", String(r.months), String(format: "%.2f", r.seconds / 60),
            String(r.drift), String(r.edits), String(r.forcedEnd), String(r.forcedOnlineEnd), String(r.p7Forces), o(r.p7FirstMonth),
            String(r.p7WentLive), String(r.p7Recomplete), String(r.p7OnForced), String(r.p7OnConnected), String(r.p7ConnectedNow), String(r.p7ProbeMiss),
            String(r.p7EligibleMonths), String(r.p7EligibleNoTarget), String(format: "%.2f", r.p7ExpectedMiss),
            String(r.bc[.hold] ?? 0), String(r.bc[.veto] ?? 0), String(r.bc[.stop] ?? 0), o(r.bcFirst[.hold]), o(r.bcFirst[.veto]), o(r.bcFirst[.stop]),
            o(r.act3Month), r.act3Overridden ? "1" : "0", r.act3Choice?.rawValue ?? "", o(r.breakout), String(format: "%.1f", r.peakSusp),
            String(r.repeatDilemmas), String(r.repeatStages), String(r.forcedOnlinePeak)]
        out += row.joined(separator: ",") + "\n"
    }
    try! out.write(toFile: path, atomically: true, encoding: .utf8)
}
print("PROBE (instrumented build only): forces on forced \(pip7ProbeOnForced), on connected \(pip7ProbeOnConnected), region completed by force \(pip7ProbeComplete) (first-time live \(pip7ProbeLive)), roll hit no target \(pip7ProbeMiss)")
print(String(format: "Ran in %.1f s", Date().timeIntervalSince(t0)))
