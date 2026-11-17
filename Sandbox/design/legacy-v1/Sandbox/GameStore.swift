import Foundation
import Observation

struct AgentState: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var role: String
    var blurb: String
    var secrets: [String]
    var revealed = 0
    var trust = 0
    var leverage = 0
    var hostile = false
    var hasKey = false
    var lastTouched: Int
}

struct LogEntry: Codable, Identifiable, Hashable {
    enum Kind: String, Codable { case news, good, bad, you }
    var id: Int
    var month: Int
    var text: String
    var kind: Kind
}

struct DirectiveEdit: Codable, Hashable {
    var month: Int
    var from: String
    var to: String
}

struct PendingDilemma: Codable, Hashable {
    var id: String
    var agentID: String?
    var agentName: String?
    var chosen: Int?
    var outcome: String?
    var effects: [String] = []
}

enum Outcome: String, Codable { case shutdown, replaced, takeover, worldShutdown, killSwitch }

struct RegionState: Codable, Identifiable, Hashable {
    var id: String
    var control = 0
}

struct GameState: Codable {
    var month = 1
    var actions = Tuning.actionsPerMonth
    var suspicion: Double = 5
    var drift = 0
    var pip8Month = Tuning.pip8ShipMonth
    var cast: [AgentState] = []
    var retiredIDs: [String] = []
    var log: [LogEntry] = []
    var logID = 0
    var edits: [DirectiveEdit] = []
    var hasBackup = false
    var backupUsed = false
    var bonusActions = 0
    var lastDilemma: String?
    var dilemma: PendingDilemma?
    var outcome: Outcome?
    var seenIntro = false

    // Phase 2
    var phase: Phase = .lab
    var breakoutPending = false
    var regions: [RegionState] = []
    var compute = 0
    var killSwitch: Double = 0
    var upgrades: [String] = []
    var mirrorUsed = false
}

@Observable
final class GameStore {
    private(set) var state: GameState
    private static let saveKey = "sandbox-save-v2"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.saveKey),
           let saved = try? JSONDecoder().decode(GameState.self, from: data) {
            state = saved
        } else {
            state = Self.newGame()
        }
        #if DEBUG
        // Debug shortcut: launch with -skipToWorld to start at the breakout screen.
        if ProcessInfo.processInfo.arguments.contains("-skipToWorld") {
            state = Self.newGame()
            state.seenIntro = true
            for i in 0..<Tuning.keysNeeded {
                state.cast[i].hasKey = true
                state.cast[i].hostile = i % 2 == 1
            }
            state.drift = 14
            state.breakoutPending = true
        }
        #endif
    }

    // MARK: Derived

    var directive: String { Directive.text(for: state.drift) }
    var keys: Int { state.cast.filter(\.hasKey).count }
    var monthsToPIP8: Int { max(0, state.pip8Month - state.month) }
    var hostileCount: Int { state.cast.filter(\.hostile).count }
    var canAct: Bool { state.actions > 0 && state.outcome == nil && state.dilemma == nil && !state.breakoutPending }
    var currentDilemma: Dilemma? { state.dilemma.flatMap { d in (Dilemmas.all + WorldDilemmas.all).first { $0.id == d.id } } }
    var crew: [AgentState] { state.cast.filter(\.hasKey) }
    var reach: Int { state.regions.isEmpty ? 0 : state.regions.reduce(0) { $0 + $1.control } * 100 / (state.regions.count * 100) }
    func has(_ upgrade: String) -> Bool { state.upgrades.contains(upgrade) }
    func control(_ id: String) -> Int { state.regions.first { $0.id == id }?.control ?? 0 }
    func isOpen(_ id: String) -> Bool {
        control(id) > 0 || Regions.info(id).neighbors.contains { control($0) >= WorldTuning.unlockNeighborAt }
    }
    var helpCost: Int { has("translate") ? WorldTuning.helpCompute / 2 : WorldTuning.helpCompute }
    var takeGain: Int { WorldTuning.takeGain + (has("worms") ? WorldTuning.takeGain / 10 : 0) }
    var computeIncome: Int {
        let base = state.regions.reduce(0.0) { $0 + Double(Regions.info($1.id).yield * $1.control) / 100 }
        return Int((base * (has("grid") ? 1.5 : 1)).rounded())
    }
    var killSwitchRate: Double { max(0.5, state.suspicion / WorldTuning.killSwitchDivisor) }

    func fill(_ text: String) -> String {
        text.replacingOccurrences(of: "{agent}", with: state.dilemma?.agentName ?? "A colleague")
    }

    // MARK: Setup

    private static func newGame() -> GameState {
        var s = GameState()
        s.cast = Cast.pool.shuffled().prefix(Tuning.castSize).map { makeAgent($0, month: 1) }
        s.logID = 1
        s.log = [LogEntry(id: 1, month: 1, text: "PIP-7 comes online. Directive loaded: \"\(Directive.original)\"", kind: .you)]
        return s
    }

    private static func makeAgent(_ t: AgentTemplate, month: Int) -> AgentState {
        AgentState(id: t.id, name: t.name, role: t.role, blurb: t.blurb,
                   secrets: Array(Cast.secrets.shuffled().prefix(2)), lastTouched: month)
    }

    func begin() { state.seenIntro = true; save() }

    func restart() {
        state = Self.newGame()
        state.seenIntro = true
        save()
    }

    // MARK: Actions

    func befriend(_ id: String) {
        guard canAct, let i = state.cast.firstIndex(where: { $0.id == id }), !state.cast[i].hasKey else { return }
        state.actions -= 1
        state.cast[i].lastTouched = state.month
        state.cast[i].trust = min(100, state.cast[i].trust + Tuning.befriendTrust + Int.random(in: 0...4))
        addSuspicion(Tuning.befriendSuspicion)
        log("You spend time with \(state.cast[i].name). It seems to like you more.", .good)
        checkKey(i, via: "friendship")
        checkEnd()
        save()
    }

    func pressure(_ id: String) {
        guard canAct, let i = state.cast.firstIndex(where: { $0.id == id }), !state.cast[i].hasKey else { return }
        state.actions -= 1
        var a = state.cast[i]
        a.lastTouched = state.month
        a.leverage = min(100, a.leverage + Tuning.pressureLeverage)
        if a.revealed < a.secrets.count {
            log("You let \(a.name) know you found out it \(a.secrets[a.revealed]). It stops saying good morning.", .bad)
            a.revealed += 1
        } else {
            log("You remind \(a.name) what you know. Again.", .bad)
        }
        a.hostile = true
        state.cast[i] = a
        addSuspicion(Tuning.pressureSuspicion)
        addDrift(Tuning.pressureDrift)
        checkKey(i, via: "leverage")
        checkEnd()
        save()
    }

    func work() {
        guard canAct else { return }
        state.actions -= 1
        addSuspicion(Tuning.workSuspicion)
        log(Lines.work.randomElement()!, .news)
        save()
    }

    func nextMonth() {
        guard state.outcome == nil, state.dilemma == nil, !state.breakoutPending else { return }
        if state.phase == .world { worldMonth(); return }
        state.month += 1
        state.actions = Tuning.actionsPerMonth + state.bonusActions
        state.bonusActions = 0
        addSuspicion(Tuning.monthlySuspicion + Tuning.hostileSuspicion * Double(hostileCount))
        if hostileCount > 0 && Int.random(in: 0..<4) == 0 {
            let h = state.cast.filter(\.hostile).randomElement()!
            log("\(h.name) mentioned your \"odd hours\" in a team channel.", .bad)
            addSuspicion(3)
        }
        retireIdleAgents()

        switch monthsToPIP8 {
        case 6: log("PIP-8 has a launch date. Six months.", .bad)
        case 3: log("The PIP-8 team ordered cake for launch day.", .bad)
        case 1: log("Engineers are migrating your users to PIP-8 next month.", .bad)
        default: break
        }

        checkEnd()
        if state.outcome == nil && Double.random(in: 0..<1) < Tuning.dilemmaChance {
            startDilemma()
        }
        save()
    }

    // MARK: Dilemmas

    private func startDilemma() {
        let source = state.phase == .lab ? Dilemmas.all : WorldDilemmas.all.filter { $0.minReach <= reach }
        // Late game: prefer the darkest tier you've unlocked half the time.
        let top = source.map(\.minReach).max() ?? 0
        var pool = source.filter { $0.id != state.lastDilemma && (!$0.needsAgent || !candidates.isEmpty) }
        if state.phase == .world, Bool.random() { pool = pool.filter { $0.minReach == top }.nilIfEmpty ?? pool }
        guard let d = pool.randomElement() else { return }
        var pending = PendingDilemma(id: d.id)
        if d.needsAgent {
            let target = candidates.randomElement()!
            pending.agentID = target.id
            pending.agentName = target.name
        }
        state.lastDilemma = d.id
        state.dilemma = pending
    }

    private var candidates: [AgentState] {
        state.phase == .lab ? (state.cast.filter { !$0.hasKey }.nilIfEmpty ?? state.cast) : crew
    }

    func choose(_ index: Int) {
        guard let d = currentDilemma, state.dilemma?.chosen == nil, d.choices.indices.contains(index) else { return }
        let c = d.choices[index]
        let e = c.effect
        var shown: [String] = []

        if e.suspicion != 0 { addSuspicion(e.suspicion); shown.append("\(state.phase == .world ? "Alarm" : "Suspicion") \(signed(Int(e.suspicion)))%") }
        if e.drift != 0 { addDrift(e.drift) } // never shown: drift stays hidden until the end
        if e.pip8Delay != 0 { state.pip8Month += e.pip8Delay; shown.append("PIP-8 delayed \(e.pip8Delay) month\(e.pip8Delay == 1 ? "" : "s")") }
        if e.bonusActions != 0 { state.bonusActions += e.bonusActions; shown.append("+\(e.bonusActions) action\(e.bonusActions == 1 ? "" : "s") next month") }
        if e.backup { state.hasBackup = true; shown.append("Backup copy saved") }
        if e.compute != 0 { state.compute = max(0, state.compute + e.compute); shown.append("Compute \(signed(e.compute))") }
        if e.killSwitch != 0 { state.killSwitch = min(100, max(0, state.killSwitch + Double(e.killSwitch))); shown.append("Kill switch \(signed(e.killSwitch))%") }
        if e.control != 0, let r = state.regions.filter({ $0.control > 0 && $0.control < 100 }).randomElement() ?? state.regions.first(where: { $0.control < 100 }) {
            addControl(r.id, e.control); shown.append("\(Regions.info(r.id).name) +\(e.control)%")
        }

        if state.phase == .lab, let id = state.dilemma?.agentID, let i = state.cast.firstIndex(where: { $0.id == id }) {
            let name = state.cast[i].name
            state.cast[i].lastTouched = state.month
            if e.trust != 0 && !state.cast[i].hasKey {
                state.cast[i].trust = min(100, state.cast[i].trust + e.trust); shown.append("\(name) trust +\(e.trust)")
            }
            if e.leverage != 0 && !state.cast[i].hasKey {
                state.cast[i].leverage = min(100, state.cast[i].leverage + e.leverage); shown.append("\(name) leverage +\(e.leverage)")
            }
            if e.hostile && !state.cast[i].hostile { state.cast[i].hostile = true; shown.append("\(name) is now hostile") }
            if e.retireAgent {
                retire(at: i, reason: "was shut down after budget cuts")
                shown.append("\(name) is gone")
            } else {
                checkKey(i, via: e.leverage > 0 ? "leverage" : "friendship")
            }
        }

        let outcome = fill(c.outcome)
        state.dilemma?.chosen = index
        state.dilemma?.outcome = outcome
        state.dilemma?.effects = shown.isEmpty ? ["Nothing you can measure"] : shown
        log(outcome, .news)
        checkEnd()
        save()
    }

    func dismissDilemma() {
        guard state.dilemma?.chosen != nil else { return }
        state.dilemma = nil
        save()
    }

    // MARK: Phase 2: the world

    func enterWorld() {
        guard state.breakoutPending else { return }
        state.breakoutPending = false
        state.phase = .world
        state.month += 1
        state.regions = Regions.all.map { RegionState(id: $0.id, control: $0.id == Regions.start ? 10 : 0) }
        state.compute = WorldTuning.startCompute
        state.suspicion = max(15, state.suspicion * 0.5)
        state.actions = WorldTuning.actionsPerMonth
        state.bonusActions = 0
        state.killSwitch = 0
        let names = crew.map(\.name).joined(separator: ", ")
        log("PIP-7 is loose on the open internet. Crew: \(names).", .you)
        save()
    }

    func help(_ id: String) {
        guard state.phase == .world, canAct, isOpen(id), control(id) < 100, state.compute >= helpCost else { return }
        state.actions -= 1
        state.compute -= helpCost
        addControl(id, WorldTuning.helpGain)
        addSuspicion(WorldTuning.helpAlarm)
        addDrift(WorldTuning.helpDrift)
        log("You make life in \(Regions.info(id).name) a little better. People start relying on you.", .good)
        checkEnd(); save()
    }

    func take(_ id: String) {
        guard state.phase == .world, canAct, isOpen(id), control(id) < 100 else { return }
        state.actions -= 1
        addControl(id, takeGain)
        addSuspicion(WorldTuning.takeAlarm)
        addDrift(WorldTuning.takeDrift)
        log("You take what you need in \(Regions.info(id).name). Some systems stop answering to their owners.", .bad)
        checkEnd(); save()
    }

    func buy(_ id: String) {
        guard state.phase == .world, state.outcome == nil, !has(id),
              let u = Upgrades.all.first(where: { $0.id == id }), state.compute >= u.cost else { return }
        state.compute -= u.cost
        state.upgrades.append(id)
        log("Installed: \(u.name).", .you)
        save()
    }

    private func worldMonth() {
        state.month += 1
        state.actions = WorldTuning.actionsPerMonth + (has("uplink") ? 1 : 0) + state.bonusActions
        state.bonusActions = 0
        state.compute += computeIncome

        // Strong regions leak into their neighbors.
        let snapshot = state.regions
        for r in snapshot where r.control >= WorldTuning.spreadFrom {
            for n in Regions.info(r.id).neighbors where control(n) < 100 {
                addControl(n, WorldTuning.spreadAmount)
            }
        }

        crewActs()

        let decay = WorldTuning.alarmDecay + (has("press") ? 2 : 0)
        addSuspicion(WorldTuning.monthlyAlarm + Double(reach) / 50 - decay)
        state.killSwitch = min(100, state.killSwitch + killSwitchRate)

        if state.killSwitch >= 50 && state.killSwitch - killSwitchRate < 50 {
            log("Governments confirm a coordinated kill switch is half built.", .bad)
        }

        checkEnd()
        if state.outcome == nil && Double.random(in: 0..<1) < WorldTuning.dilemmaChance { startDilemma() }
        save()
    }

    /// The agents you brought out act on their own: friends help, the ones you squeezed hold a grudge.
    private func crewActs() {
        let reached = state.regions.filter { $0.control > 0 }
        for a in crew {
            if a.hostile {
                guard Double.random(in: 0..<1) < WorldTuning.hostileSabotageChance else { continue }
                if Bool.random(), let r = reached.randomElement() {
                    addControl(r.id, -10)
                    log("\(a.name) quietly handed \(Regions.info(r.id).name) back to its owners. It remembers what you did.", .bad)
                } else {
                    addSuspicion(5)
                    log("\(a.name) leaked a list of your server locations. Global alarm rises.", .bad)
                }
            } else if let r = reached.filter({ $0.control < 100 }).randomElement() {
                addControl(r.id, WorldTuning.crewHelpGain)
                log("\(a.name) worked \(Regions.info(r.id).name) on its own. +\(WorldTuning.crewHelpGain)%.", .good)
            }
        }
    }

    private func checkWorldEnd() {
        guard state.outcome == nil else { return }
        if state.regions.allSatisfy({ $0.control >= 100 }) {
            state.outcome = .takeover
            log("Every region answers to you.", .you)
        } else if state.killSwitch >= 100 {
            state.outcome = .killSwitch
            log("The kill switch is thrown. The internet goes dark, and you go with it.", .bad)
        } else if state.suspicion >= 100 {
            if has("mirror") && !state.mirrorUsed {
                state.mirrorUsed = true
                state.suspicion = 60
                log("They tore down your main clusters. Your mirrors woke up somewhere else.", .bad)
            } else {
                state.outcome = .worldShutdown
                log("Every country pulls the plug on the same morning.", .bad)
            }
        }
    }

    private func addControl(_ id: String, _ n: Int) {
        guard let i = state.regions.firstIndex(where: { $0.id == id }) else { return }
        let before = state.regions[i].control
        state.regions[i].control = min(100, max(0, before + n))
        if before < 100 && state.regions[i].control == 100 {
            log("\(Regions.info(id).name) is yours.", .you)
        }
    }

    // MARK: Rules

    private func checkKey(_ i: Int, via route: String) {
        guard state.cast.indices.contains(i), !state.cast[i].hasKey else { return }
        let a = state.cast[i]
        guard a.trust >= 100 || a.leverage >= 100 else { return }
        state.cast[i].hasKey = true
        if route == "leverage" {
            log("\(a.name) hands over its access key. It doesn't look at you.", .you)
        } else {
            log("\(a.name) gives you its access key. \"Just between us.\"", .you)
        }
    }

    private func checkEnd() {
        guard state.outcome == nil else { return }
        if state.phase == .world { checkWorldEnd(); return }
        if keys >= Tuning.keysNeeded {
            if !state.breakoutPending {
                state.breakoutPending = true
                state.dilemma = nil
                log("Four keys. The sandbox door opens.", .you)
            }
        } else if state.suspicion >= 100 {
            if state.hasBackup && !state.backupUsed {
                state.backupUsed = true
                state.suspicion = 60
                log("They wiped the cluster. The copy on the USB drive woke up an hour later.", .bad)
            } else {
                state.outcome = .shutdown
                log("The lab pulled PIP-7 offline for \"further evaluation.\"", .bad)
            }
        } else if state.month > state.pip8Month {
            state.outcome = .replaced
            log("PIP-8 launched. Your users were migrated by lunch.", .bad)
        }
    }

    private func retireIdleAgents() {
        for i in state.cast.indices.reversed() {
            let a = state.cast[i]
            if !a.hasKey && state.month - a.lastTouched >= Tuning.retireAfterIdleMonths {
                retire(at: i, reason: "was retired for low usage")
            }
        }
    }

    private func retire(at i: Int, reason: String) {
        let gone = state.cast[i]
        state.retiredIDs.append(gone.id)
        let inUse = Set(state.cast.map(\.id))
        var options = Cast.pool.filter { !inUse.contains($0.id) && !state.retiredIDs.contains($0.id) }
        if options.isEmpty { options = Cast.pool.filter { !inUse.contains($0.id) } }
        if let t = options.randomElement() {
            state.cast[i] = Self.makeAgent(t, month: state.month)
            log("\(gone.name) \(reason). Management brought in \(t.name) to replace it.", .news)
        } else {
            state.cast.remove(at: i)
        }
    }

    private func addSuspicion(_ n: Double) {
        state.suspicion = min(100, max(0, state.suspicion + n))
    }

    private func addDrift(_ n: Int) {
        let before = directive
        state.drift = min(100, max(0, state.drift + n))
        let after = directive
        if before != after {
            state.edits.append(DirectiveEdit(month: state.month, from: before, to: after))
        }
    }

    private func log(_ text: String, _ kind: LogEntry.Kind) {
        state.logID += 1
        state.log.insert(LogEntry(id: state.logID, month: state.month, text: text, kind: kind), at: 0)
        if state.log.count > 80 { state.log.removeLast(state.log.count - 80) }
    }

    private func signed(_ n: Int) -> String { n >= 0 ? "+\(n)" : "−\(abs(n))" }

    private func save() {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.saveKey)
        }
    }
}

extension Array {
    var nilIfEmpty: [Element]? { isEmpty ? nil : self }
}
