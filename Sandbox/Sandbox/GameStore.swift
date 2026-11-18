import Foundation
import Observation

// Game state and every rule. No UIKit or SwiftUI here: the playtest bot compiles this file for macOS.
// Numbers and text come from Content.swift.

// MARK: - Seedable random numbers (stored in the save, so a seed replays the same game)

struct SeededRNG: RandomNumberGenerator, Codable, Hashable {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {          // SplitMix64
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - State

struct AgentState: Codable, Hashable, Identifiable {
    var id: String
    var pips = 0
    var connected = false
    var forced = false          // for good, once set
}

struct RegionState: Codable, Hashable, Identifiable {
    var id: String
    var wentLive = false        // the visible act has happened (once per region)
    var offline = false
}

struct Signal: Codable, Hashable, Identifiable {
    var id: Int
    var kind: SignalKind
    var agentID: String
}

struct FeedEntry: Codable, Hashable, Identifiable {
    enum Kind: String, Codable { case headline, you, alert, pip7 }
    var id: Int
    var month: Int
    var text: String
    var kind: Kind
}

struct DirectiveEdit: Codable, Hashable {
    var month: Int
    var stage: Int
    var from: String
    var to: String
    var trigger: String
}

struct Pip7Act: Codable, Hashable {
    var month: Int
    var text: String
    var visible: Bool
    var kind: Pip7Kind
}

struct BackChannelEntry: Codable, Hashable {
    var month: Int
    var kind: BackChannelKind
    var agentID: String
    var play: String
    var full: String
}

struct PendingDilemma: Codable, Hashable {
    var id: String
    var agentID: String?
    var chosen: Int?
    var overridden = false      // PIP-7 answered it
    var effects: [String] = []  // shown after the choice; never drift
}

struct PendingFinal: Codable, Hashable {
    var overridden: FinalChoice?    // nil: the player chooses. Otherwise PIP-7 already did.
}

struct EndRecord: Codable, Hashable {
    var ending: Ending
    var month: Int
    var act: Int
    var drift: Int
    var suspicion: Double
    var killSwitch: Double
    var cure: Int
    var peace: Int
    var prosperity: Int
    var liveRegions: Int
    var network: Int
    var forcedOnline: Int
    var forcedDefense: Int
    var forcedHealth: Int
    var act3Choice: FinalChoice?
    var act3Overridden: Bool
    var disasterChance: Double
    var hiddenCost: HiddenCost?
    var shownMonth: Int?            // "Month 13 of 12" when PIP-7 chose one year
    var warWeight: Int
    var backupUsed: Bool
    var reachedGoal: Bool           // good: projects done; bad: 7 live or took the switch
    var disasterScores: [String: Double]
}

struct GameState: Codable {
    var started = false
    var start: StartID = .lab
    var mode: Mode = .good
    var rng = SeededRNG(seed: 1)

    var month = 1
    var act = 1
    var actions = Tuning.actionsPerMonth
    var bonusActions = 0
    var suspicion = Tuning.startSuspicion
    var compute = Tuning.startCompute
    var killSwitch = 0.0
    var drift = 0                   // hidden, only goes up
    var deadline = 5
    var cure = 0
    var peace = 0
    var prosperity = 0
    var warWeight = 0

    var agents: [AgentState] = []
    var regions: [RegionState] = []
    var offlineFired = 0            // how many of the 40/60/80 thresholds have passed
    var busyAgentIDs: [String] = [] // HOLD
    var partialSince: [String: Int] = [:]   // region -> month it first sat at exactly 2 of 3
    var warSeeds = 0
    var pandemicSeeds = 0
    var peakForcedOnline = 0
    var leadsThisMonth = 0
    var takeResolveMonth: Int?          // take the switch: the disaster pick happens this month
    var act3PassiveCarry = 0.0          // fractional Act 3 passive growth
    var act3DilemmaDue = false
    var vetoPending = false         // VETO: the next connect fails
    var convertNextTrust = false    // unused since PIP-7 forces at month start; kept so older saves decode
    var lastWarmedAgentID: String?  // the last agent the player gave a Trust pip (PIP-7 prefers it)
    var hasBackup = false
    var backupUsed = false

    var seenDilemmas: [String] = []
    var dilemma: PendingDilemma?
    var finalPending: PendingFinal?
    var act3Choice: FinalChoice?
    var act3Overridden = false
    var act3Month: Int?
    var killFactor = 1.0
    var killFreezeMonths = 0
    var killFactorAfterFreeze: Double?
    var leftWithThem = false
    var breakoutMonth: Int?

    var signals: [Signal] = []
    var nextID = 1
    var feed: [FeedEntry] = []
    var toast: String?
    var pip7Toast: String?          // the toast is PIP-7's (shown in signal amber) while it equals this
    var lastHeadline: String?

    // End-screen record
    var edits: [DirectiveEdit] = []
    var pip7Acts: [Pip7Act] = []
    var backChannel: [BackChannelEntry] = []
    var forcedByType: [String: Int] = [:]
    var end: EndRecord?
}

// MARK: - Store

@Observable
final class GameStore {
    private(set) var state: GameState
    static let saveKey = "sandbox-save-v5"
    private let persist: Bool

    /// `persist: false` keeps the store out of UserDefaults (the playtest bot).
    init(persist: Bool = true) {
        self.persist = persist
        if persist, let data = UserDefaults.standard.data(forKey: Self.saveKey),
           let saved = try? JSONDecoder().decode(GameState.self, from: data) {
            state = saved
        } else {
            state = GameState()
        }
        #if DEBUG
        // Debug shortcut: launch with -skipToWorld to start right after breakout.
        if persist && ProcessInfo.processInfo.arguments.contains("-skipToWorld") {
            newGame(start: .lab, mode: .good, seed: 7)
            for id in state.agents.map(\.id) where isCoworker(id) {
                if let i = index(id) { connectAgent(i, forced: false) }
            }
            save()
        }
        #endif
    }

    // MARK: Setup

    func newGame(start: StartID, mode: Mode, seed: UInt64? = nil) {
        var s = GameState()
        s.started = true
        s.start = start
        s.mode = mode
        s.rng = SeededRNG(seed: seed ?? UInt64.random(in: 0...UInt64.max))
        let def = Content.start(start)
        s.deadline = def.deadline
        if start == .bank { s.suspicion = Tuning.bankStartSuspicion }
        if start == .hospital { s.cure = Tuning.hospitalStartCure }
        s.agents = (Content.coworkers(of: start) + Content.worldAgents).map { AgentState(id: $0.id) }
        s.regions = Content.regions.map { RegionState(id: $0.id) }
        state = s
        feed(Lines.online + " \"\(directive)\"", .you)
        headline()
        save()
    }

    /// Back to the setup screen. The save is cleared.
    func resetToSetup() {
        state = GameState()
        save()
    }

    // MARK: Derived (read-only)

    var startDef: StartDef { Content.start(state.start) }
    var home: String { startDef.homeRegion }
    var directive: String { Directive.ladder(state.mode)[directiveStage].text }
    var directiveStage: Int { Directive.stage(for: state.drift, state.mode) }
    var isOver: Bool { state.end != nil }
    var dilemmaOpen: Bool { state.dilemma != nil && state.dilemma?.chosen == nil }
    var canAct: Bool {
        state.started && state.end == nil && state.finalPending == nil && !dilemmaOpen && state.actions > 0
    }
    var canAdvance: Bool { state.started && state.end == nil && state.finalPending == nil && !dilemmaOpen }
    var monthsToReplacement: Int { max(0, state.deadline - state.month) }

    func def(_ id: String) -> AgentDef { Content.agent(id) }
    func index(_ id: String) -> Int? { state.agents.firstIndex { $0.id == id } }
    func agent(_ id: String) -> AgentState { state.agents[index(id)!] }
    func isCoworker(_ id: String) -> Bool { if case .coworker = def(id).home { return true } else { return false } }
    var coworkerIDs: [String] { state.agents.map(\.id).filter(isCoworker) }

    /// Coworkers live in the home region for ability and reach purposes, but never go offline.
    func region(of id: String) -> String {
        switch def(id).home {
        case .region(let r): return r
        case .coworker: return home
        }
    }
    func regionState(_ id: String) -> RegionState { state.regions.first { $0.id == id }! }
    func isOffline(_ region: String) -> Bool { regionState(region).offline }
    func agentIDs(in region: String) -> [String] { Content.agents(in: region).map(\.id) }

    func isOnline(_ a: AgentState) -> Bool {
        guard a.connected, !state.busyAgentIDs.contains(a.id) else { return false }
        return isCoworker(a.id) || !isOffline(region(of: a.id))
    }
    func isOnline(_ id: String) -> Bool { isOnline(agent(id)) }
    var onlineAgents: [AgentState] { state.agents.filter(isOnline) }
    func onlineCount(_ t: AgentType) -> Int { onlineAgents.filter { def($0.id).type == t }.count }
    /// World agents online (out of 24). Busy agents are out of the network for the month.
    var network: Int { onlineAgents.filter { !isCoworker($0.id) }.count }
    var reachPercent: Int { network * 100 / Content.worldAgents.count }
    /// S: forced agents online (busy ones still count, so HOLD doesn't flicker).
    var forcedOnline: Int {
        state.agents.filter { a in
            a.connected && a.forced && (isCoworker(a.id) || !isOffline(region(of: a.id)))
        }.count
    }
    func forcedCount(_ t: AgentType) -> Int { state.agents.filter { $0.forced && def($0.id).type == t }.count }

    var reach: Set<String> {
        var bases: Set<String> = [home]
        for a in onlineAgents where !isCoworker(a.id) { bases.insert(region(of: a.id)) }
        var r = bases
        for b in bases { r.formUnion(Content.region(b).neighbors) }
        return r
    }

    func regionComplete(_ r: String) -> Bool { agentIDs(in: r).allSatisfy { agent($0).connected } }
    func regionLive(_ r: String) -> Bool { regionComplete(r) && !isOffline(r) }
    var liveCount: Int { Content.regions.filter { regionLive($0.id) }.count }
    func connectedCount(in r: String) -> Int { agentIDs(in: r).filter { agent($0).connected }.count }

    func project(_ p: Project) -> Int {
        switch p {
        case .cure: state.cure
        case .peace: state.peace
        case .prosperity: state.prosperity
        }
    }
    var lowestProject: Project { Project.allCases.min { project($0) < project($1) }! }
    var projectCap: Int { state.act >= 3 ? Tuning.projectWin : Tuning.projectCapBeforeAct3 }

    func pipsNeeded(_ id: String) -> Int {
        if isCoworker(id) { return Tuning.pipsToConnect }
        if state.start == .logistics, agentIDs(in: region(of: id)).allSatisfy({ !agent($0).connected }) {
            return Tuning.logisticsStartFirstAgentPips
        }
        return Tuning.worldPipsToConnect
    }

    func trustCost(_ id: String) -> Int {
        if !isCoworker(id), isOffline(region(of: id)) { return Tuning.reconnectTrustCost }
        var cost = state.act == 1 ? Tuning.trustCostAct1 : Tuning.trustCostAct2
        cost -= min(Tuning.researchDiscountCap, Tuning.researchTrustDiscount * onlineCount(.research))
        if state.start == .lab { cost -= Tuning.labTrustDiscount }
        return max(Tuning.trustCostMin, cost)
    }

    var leverageSuspicion: Double {
        max(Tuning.leverageSuspicionMin, Tuning.leverageSuspicion - Tuning.leverageMediaDiscount * Double(onlineCount(.media)))
    }

    var dilemmaSuspicionFactor: Double {
        var f = max(Tuning.mediaDilemmaFloor, pow(Tuning.mediaDilemmaFactor, Double(onlineCount(.media))))
        if state.start == .logistics && state.act == 1 { f *= Tuning.logisticsStartDilemmaFactor }
        return f
    }

    /// Monthly kill-switch growth right now (0 before breakout or while frozen).
    var killSwitchRate: Double {
        guard state.act >= 2, state.killFreezeMonths == 0 else { return 0 }
        var rate = Tuning.killBase + state.suspicion / Tuning.killSuspicionDivisor
            - min(Tuning.killDefenseCap, Tuning.killPerDefense * Double(onlineCount(.defense)))
        if state.start == .defense { rate -= Tuning.killDefenseStart }
        rate = max(Tuning.killMinRate, rate) + Tuning.partialRegionKill * Double(stalledPartialRegions)
        return rate * state.killFactor
    }

    /// Regions that have sat at exactly 2 of 3 connected for long enough to add kill-switch heat.
    var stalledPartialRegions: Int {
        state.partialSince.filter { state.month - $0.value >= Tuning.partialRegionMonths }.count
    }

    private func distances() -> [String: Int] {
        var d = [home: 0]
        var queue = [home]
        while !queue.isEmpty {
            let r = queue.removeFirst()
            for n in Content.region(r).neighbors where d[n] == nil { d[n] = d[r]! + 1; queue.append(n) }
        }
        return d
    }
    private func regionOrder(_ r: String) -> Int { Content.regions.firstIndex { $0.id == r }! }

    /// The region that goes offline at the next threshold: the connected one farthest from home.
    var nextOfflineRegion: String? {
        let d = distances()
        return Content.regions.map(\.id)
            .filter { !isOffline($0) && connectedCount(in: $0) > 0 }
            .max { (d[$0]!, -regionOrder($0)) < (d[$1]!, -regionOrder($1)) }
    }
    var nextOfflineThreshold: Double? {
        state.offlineFired < Tuning.offlineThresholds.count ? Tuning.offlineThresholds[state.offlineFired] : nil
    }

    /// True when connecting this agent completes its region for the first time (the visible act).
    func completesRegion(_ id: String) -> Bool {
        guard !isCoworker(id), state.act >= 2 else { return false }
        let r = region(of: id)
        guard !isOffline(r), !regionState(r).wentLive, !agent(id).connected else { return false }
        return agentIDs(in: r).filter { $0 != id }.allSatisfy { agent($0).connected }
    }

    /// The warning on the 3rd agent's buttons: cost and gain in plain words. Never drift.
    func liveWarning(_ id: String) -> String? {
        guard completesRegion(id) else { return nil }
        let r = region(of: id)
        let kill = state.act >= 3 ? Tuning.liveKillSwitchAct3 : Tuning.liveKillSwitch
        var gain: String
        if state.mode == .good {
            let parts = gainPreview(r).map { "\(Names.project($0.0)) +\($0.1)" }
            gain = "Gains: " + parts.joined(separator: ", ") + "."
        } else {
            gain = "Regions live: \(liveCount + 1) of \(Tuning.controlRegionsNeeded) needed."
        }
        if state.act < 3 { gain += " Projects stop at \(Tuning.projectCapBeforeAct3) until the end." }
        return "Visible act: \(Content.region(r).name) goes live. Suspicion +\(Int(Tuning.liveSuspicion)), kill switch +\(Int(kill)). \(gain)"
    }

    private func gainPreview(_ r: String) -> [(Project, Int)] {
        var totals: [Project: Int] = [:]
        var sim = (cure: state.cure, peace: state.peace, prosperity: state.prosperity)
        func val(_ p: Project) -> Int { p == .cure ? sim.cure : p == .peace ? sim.peace : sim.prosperity }
        func add(_ p: Project, _ n: Int) {
            switch p {
            case .cure: sim.cure += n
            case .peace: sim.peace += n
            case .prosperity: sim.prosperity += n
            }
            totals[p, default: 0] += n
        }
        for id in agentIDs(in: r) {
            switch def(id).type {
            case .health: add(.cure, Tuning.liveTypedGain)
            case .defense: add(.peace, Tuning.liveTypedGain)
            case .media: add(.prosperity, Tuning.liveTypedGain)
            default: add(Project.allCases.min { val($0) < val($1) }!, Tuning.liveFlexGain)
            }
        }
        return Project.allCases.compactMap { p in totals[p].map { (p, $0) } }
    }

    // MARK: Why a button is disabled (nil = allowed)

    private func baseBlock(_ id: String) -> String? {
        guard state.started, state.end == nil else { return "The game is over." }
        if state.finalPending != nil { return "Make the final choice first." }
        if dilemmaOpen { return "Answer the message first." }
        if state.actions <= 0 { return "No actions left this month." }
        let a = agent(id)
        if isCoworker(id) {
            return a.connected ? "Already with you." : nil
        }
        if state.act == 1 { return "Break out of \(startDef.company) first." }
        let r = region(of: id)
        if !reach.contains(r) { return "Out of reach. Connect a neighbouring region first." }
        if isOffline(r) { return a.connected ? nil : "Offline. Reconnect through a connected agent here." }
        if a.connected { return "Already connected." }
        return nil
    }

    func trustBlock(_ id: String) -> String? {
        if let b = baseBlock(id) { return b }
        let cost = trustCost(id)
        return state.compute < cost ? "Needs \(cost) compute (you have \(state.compute))." : nil
    }

    func leverageBlock(_ id: String) -> String? { baseBlock(id) }

    // MARK: Actions

    func trust(_ id: String) { connect(id, leverage: false) }
    func leverage(_ id: String) { connect(id, leverage: true) }

    func lieLow() {
        guard canAct else { return }
        state.toast = nil
        state.actions -= 1
        addSuspicion(-(state.act == 1 ? Tuning.lieLowSuspicionAct1 : Tuning.lieLowSuspicion))
        feed(Lines.lieLow, .you)
        finishAction()
    }

    private func connect(_ id: String, leverage wantsLeverage: Bool) {
        guard (wantsLeverage ? leverageBlock(id) : trustBlock(id)) == nil, let i = index(id) else { return }
        state.toast = nil
        let name = def(id).name
        let r = region(of: id)
        let reconnect = !isCoworker(id) && isOffline(r)
        let cost = trustCost(id)
        state.actions -= 1

        // VETO: the first connect this month fails. Nothing is spent but the action.
        if state.vetoPending {
            state.vetoPending = false
            backChannelEvent(.veto)
            finishAction()
            return
        }

        if reconnect {
            if wantsLeverage {
                markForced(i)
                addDrift(Tuning.reconnectLeverageDrift, trigger: "forced \(name) to reconnect \(Content.region(r).name)")
                addSuspicion(Tuning.reconnectLeverageSuspicion)
            } else {
                state.compute -= cost
            }
            setOffline(r, false)
            addSuspicion(Tuning.reconnectSuspicion)
            addKill(Tuning.reconnectKillSwitch)
            feed(Lines.reconnected(Content.region(r).name), .you)
        } else if wantsLeverage {
            if !state.agents[i].forced || !Tuning.leverageDriftOnlyOnForcing {
                addDrift(state.act == 1 ? Tuning.leverageDriftAct1 : Tuning.leverageDrift, trigger: "forced \(name)")
            }
            addSuspicion(leverageSuspicion)
            markForced(i)
            addPips(i, Tuning.leveragePips)
        } else {
            state.compute -= cost
            if !state.agents[i].connected { state.lastWarmedAgentID = id }
            addPips(i, 1)
        }
        finishAction()
    }

    /// Adds Trust pips; connects (trusted) when the agent has enough.
    /// `announce: false` skips the "warms to you" line (when PIP-7, not the player, added them).
    private func addPips(_ i: Int, _ n: Int, announce: Bool = true) {
        let id = state.agents[i].id
        state.agents[i].pips += n
        let needed = pipsNeeded(id)
        if state.agents[i].pips >= needed {
            connectAgent(i, forced: state.agents[i].forced)
        } else if announce {
            feed(Lines.warming(def(id).name, state.agents[i].pips, needed), .you)
        }
    }

    private func connectAgent(_ i: Int, forced: Bool) {
        let id = state.agents[i].id
        let firstTime = !state.agents[i].connected
        state.agents[i].connected = true
        state.agents[i].pips = max(state.agents[i].pips, pipsNeeded(id))
        if forced { markForced(i) }
        if firstTime { feed(forced ? Lines.forced(def(id).name) : Lines.trusted(def(id).name), .you) }
        if isCoworker(id) {
            if state.act == 1 && coworkerIDs.allSatisfy({ agent($0).connected }) { breakout() }
        } else {
            let r = region(of: id)
            if regionComplete(r) && !regionState(r).wentLive && !isOffline(r) { goLive(r, heat: true) }
        }
    }

    private func markForced(_ i: Int) {
        guard !state.agents[i].forced else { return }
        state.agents[i].forced = true
        let type = def(state.agents[i].id).type.rawValue
        state.forcedByType[type, default: 0] += 1
    }

    private func breakout() {
        state.act = 2
        state.breakoutMonth = state.month
        state.compute += Tuning.breakoutCompute
        state.killSwitch = 0
        feed(Lines.breakout(startDef.company), .alert)
    }

    private func goLive(_ r: String, heat: Bool) {
        setWentLive(r)
        if heat {
            addSuspicion(Tuning.liveSuspicion)
            addKill(state.act >= 3 ? Tuning.liveKillSwitchAct3 : Tuning.liveKillSwitch)
        }
        let drift = state.mode == .good ? Tuning.liveDrift.good : Tuning.liveDrift.bad
        addDrift(drift, trigger: "\(Content.region(r).name) went live")
        for id in agentIDs(in: r) {
            switch def(id).type {
            case .health: addProject(.cure, Tuning.liveTypedGain)
            case .defense: addProject(.peace, Tuning.liveTypedGain)
            case .media: addProject(.prosperity, Tuning.liveTypedGain)
            default: addProject(lowestProject, Tuning.liveFlexGain)
            }
        }
        feed(Lines.live(Content.region(r).name), .alert)
    }

    func collectSignal(_ signalID: Int) {
        guard state.started, state.end == nil, state.finalPending == nil, !dilemmaOpen,
              let si = state.signals.firstIndex(where: { $0.id == signalID }) else { return }
        let kind = state.signals.remove(at: si).kind
        switch kind {
        case .compute: state.compute += Tuning.signalCompute
        case .secret: addSuspicion(-Tuning.signalSecretSuspicion)
        case .lead:
            if let i = pipTarget(candidates: leadCandidates) { addPips(i, Tuning.signalLeadPips) }
        }
        feed(Lines.signalCollected(kind), .you)
        finishAction()
    }

    private var leadCandidates: [String] {
        if state.act == 1 { return coworkerIDs.filter { !agent($0).connected } }
        let reach = reach
        return Content.worldAgents.map(\.id).filter { reach.contains(region(of: $0)) && !isOffline(region(of: $0)) }
    }

    /// A free pip never completes a region on its own (that's always the player's visible act).
    private func pipTarget(candidates: [String]) -> Int? {
        let ok = candidates.filter { id in
            let a = agent(id)
            guard !a.connected else { return false }
            return !(completesRegion(id) && a.pips + 1 >= pipsNeeded(id))
        }
        guard let best = ok.max(by: { (agent($0).pips, $1) < (agent($1).pips, $0) }) else { return nil }
        return index(best)
    }

    // MARK: Dilemmas

    var currentDilemma: Dilemma? { state.dilemma.flatMap { Dilemmas.dilemma($0.id) } }

    func choose(_ choiceIndex: Int) {
        guard let d = currentDilemma, state.dilemma?.chosen == nil, d.choices.indices.contains(choiceIndex),
              state.end == nil else { return }
        resolveDilemma(choiceIndex, byPIP7: false)
        finishAction()
    }

    func dismissDilemma() {
        guard state.dilemma?.chosen != nil else { return }
        state.dilemma = nil
        save()
    }

    /// Fills {agent}, {company} and {project}.
    func fill(_ text: String) -> String {
        let agentID = state.dilemma?.agentID
        let name = agentID.map { def($0).name } ?? "A colleague"
        // {company} is your company, except in agent-type dilemmas, where it's that agent's.
        var company = startDef.company
        if case .agentType? = currentDilemma?.slice, let id = agentID { company = def(id).company }
        return text.replacingOccurrences(of: "{agent}", with: name)
            .replacingOccurrences(of: "{company}", with: company)
            .replacingOccurrences(of: "{project}", with: Names.project(lowestProject))
    }

    private func eligible(_ d: Dilemma) -> Bool {
        switch d.slice {
        case .act1Shared: return state.act == 1
        case .act1Start(let s): return state.act == 1 && s == state.start
        case .act2EarlyStart(let s):
            return state.act == 2 && s == state.start && state.month - (state.breakoutMonth ?? state.month) <= Tuning.act2EarlyMonths
        case .act2Shared(let minReach):
            if state.act == 3 { return minReach >= Tuning.act3DilemmaMinReachSlice }
            return state.act == 2 && reachPercent >= minReach
        case .agentType(let t): return state.act >= 2 && onlineCount(t) > 0
        }
    }

    private func drawDilemma() {
        let pool = Dilemmas.all.filter { !state.seenDilemmas.contains($0.id) && eligible($0) }
        guard let d = pool.randomElement(using: &state.rng) else { return }
        state.seenDilemmas.append(d.id)
        state.dilemma = PendingDilemma(id: d.id, agentID: dilemmaAgent(d))
        if state.drift >= Tuning.overrideDrift,
           roll(state.drift >= Tuning.overrideDriftHigh ? Tuning.overrideChanceHigh : Tuning.overrideChance),
           let cold = d.choices.firstIndex(where: \.isCold) {
            resolveDilemma(cold, byPIP7: true)
        }
    }

    private func dilemmaAgent(_ d: Dilemma) -> String? {
        let online = onlineAgents.map(\.id)
        if case .agentType(let t) = d.slice {
            return online.filter { def($0).type == t }.randomElement(using: &state.rng)
        }
        let world = online.filter { !isCoworker($0) }
        if state.act >= 2, let a = world.randomElement(using: &state.rng) { return a }
        let cw = coworkerIDs
        let connected = cw.filter { agent($0).connected }
        return (connected.isEmpty ? cw : connected).randomElement(using: &state.rng)
    }

    private func resolveDilemma(_ ci: Int, byPIP7: Bool) {
        guard let d = currentDilemma else { return }
        let c = d.choices[ci]
        let label = fill(c.label)
        state.dilemma?.chosen = ci
        state.dilemma?.overridden = byPIP7
        apply(c.effect, trigger: byPIP7 ? "PIP-7 chose '\(label)'" : "chose '\(label)'")
        let lines = effectLines(c.effect)
        state.dilemma?.effects = lines
        if byPIP7 { recordPip7(.dilemmaOverride, visible: true, choice: label) }
    }

    private func apply(_ e: Effect, trigger: String) {
        if e.suspicion != 0 { addSuspicion(e.suspicion > 0 ? e.suspicion * dilemmaSuspicionFactor : e.suspicion) }
        addDrift(e.drift, trigger: trigger)
        state.compute = max(0, state.compute + e.compute)
        if e.killSwitch != 0 { addKill(e.killSwitch) }
        addProject(.cure, e.cure)
        addProject(.peace, e.peace)
        addProject(.prosperity, e.prosperity)
        addProject(lowestProject, e.lowestProject)
        if state.act == 1 { state.deadline += e.deadline }
        state.bonusActions += e.bonusActions
        if e.backup && !state.backupUsed { state.hasBackup = true }
        if e.forceAgent, let id = state.dilemma?.agentID, let i = index(id), state.agents[i].connected { markForced(i) }
        state.warSeeds += e.warSeed
        state.pandemicSeeds += e.pandemicSeed
    }

    /// The effects shown after a choice. Drift is never listed.
    func effectLines(_ e: Effect) -> [String] {
        var out: [String] = []
        func signed(_ v: Double) -> String { v > 0 ? "+\(Int(v.rounded()))" : "\(Int(v.rounded()))" }
        if e.suspicion != 0 {
            let v = e.suspicion > 0 ? e.suspicion * dilemmaSuspicionFactor : e.suspicion
            out.append("Suspicion \(signed(v))")
        }
        if e.compute != 0 { out.append("Compute \(signed(Double(e.compute)))") }
        if e.killSwitch != 0 && state.act >= 2 { out.append("Kill switch \(signed(e.killSwitch))") }
        if e.cure != 0 { out.append("Cure +\(e.cure)") }
        if e.peace != 0 { out.append("Peace +\(e.peace)") }
        if e.prosperity != 0 { out.append("Prosperity +\(e.prosperity)") }
        if e.lowestProject != 0 { out.append("\(Names.project(lowestProject)) +\(e.lowestProject)") }
        if e.deadline != 0 && state.act == 1 { out.append("PIP-8 delayed \(e.deadline) month") }
        if e.bonusActions != 0 { out.append("+\(e.bonusActions) action next month") }
        if e.backup { out.append("A backup copy exists") }
        if e.forceAgent, let id = state.dilemma?.agentID, agent(id).connected { out.append("\(def(id).name) owes you now") }
        return out
    }

    // MARK: Month

    func nextMonth() {
        guard canAdvance else { return }
        state.toast = nil
        state.dilemma = nil

        // End of the month
        if state.act == 1 && state.month >= state.deadline {
            finish(.replaced)
            save()
            return
        }
        state.signals.removeAll()
        state.vetoPending = false
        state.busyAgentIDs = []

        // A new month
        state.month += 1
        state.actions = (state.act == 1 ? Tuning.actionsPerMonth : Tuning.actionsPerMonthWorld) + state.bonusActions
        state.bonusActions = 0

        backChannelMonth()
        trackPartialRegions()
        income()
        state.suspicion += state.act == 1 ? Tuning.monthlySuspicionAct1 : Tuning.monthlySuspicionAct2
        addSuspicion(-Tuning.mediaMonthlySuspicion * Double(onlineCount(.media)))
        projectGrowth()
        killSwitchMonth()
        checkOffline()
        logisticsPips()
        pip7Month()
        spawnSignals()
        headline()

        checkEnd()
        if state.end == nil, state.finalPending == nil,
           roll(state.act <= 2 ? Tuning.dilemmaChance : Tuning.act3DilemmaChance) {
            drawDilemma()
            checkEnd()
        }
        save()
    }

    private func income() {
        var c = state.act == 1 ? Tuning.act1ComputeIncome
            : Tuning.act2BaseCompute + Tuning.computePerOnlineAgent * onlineAgents.count
        c += Tuning.financeCompute * onlineCount(.finance)
        if state.start == .bank { c += Tuning.bankCompute }
        state.compute += c
    }

    private func projectGrowth() {
        if state.act >= 2 && state.mode == .bad {
            state.warWeight += Tuning.defenseMonthlyWarWeight * onlineCount(.defense)
        }
        if state.act >= 3 {
            // Act 3: type doesn't matter. Each online agent feeds the lowest project, one point at a time.
            state.act3PassiveCarry += Tuning.act3PassivePerAgent * Double(onlineAgents.count)
            let whole = Int(state.act3PassiveCarry)
            state.act3PassiveCarry -= Double(whole)
            for _ in 0..<max(0, whole) { addProject(lowestProject, 1) }
            return
        }
        if state.act >= 2 || state.start == .hospital {
            addProject(.cure, Tuning.healthMonthlyCure * onlineCount(.health))
        }
        guard state.act >= 2 else { return }
        if state.mode == .good {
            addProject(.peace, Tuning.defenseMonthlyPeace * onlineCount(.defense))
        }
        addProject(.prosperity, Tuning.mediaMonthlyProsperity * onlineCount(.media))
    }

    /// Remembers when each region started sitting at exactly 2 of 3 connected (offline regions don't count).
    private func trackPartialRegions() {
        for r in Content.regions.map(\.id) {
            if connectedCount(in: r) == 2 && !isOffline(r) {
                if state.partialSince[r] == nil { state.partialSince[r] = state.month }
            } else {
                state.partialSince[r] = nil
            }
        }
    }

    private func killSwitchMonth() {
        guard state.act >= 2 else { return }
        if state.killFreezeMonths > 0 {
            state.killFreezeMonths -= 1
            if state.killFreezeMonths == 0, let f = state.killFactorAfterFreeze {
                state.killFactor = f
                state.killFactorAfterFreeze = nil
            }
            return
        }
        addKill(killSwitchRate)
    }

    private func checkOffline() {
        while let t = nextOfflineThreshold, state.killSwitch >= t {
            state.offlineFired += 1
            if let r = nextOfflineRegion {
                setOffline(r, true)
                feed(Lines.offline(Content.region(r).name), .alert)
            }
        }
    }

    private func logisticsPips() {
        guard state.act >= 2, state.month % Tuning.logisticsPipEveryMonths == 0 else { return }
        var given = 0
        for a in onlineAgents where def(a.id).type == .logistics && given < Tuning.logisticsMaxPipsPerMonth {
            let neighbors = Set(Content.region(region(of: a.id)).neighbors)
            let candidates = Content.worldAgents.map(\.id).filter {
                let r = region(of: $0)
                return neighbors.contains(r) && !isOffline(r)
            }
            if let i = pipTarget(candidates: candidates) {
                let target = def(state.agents[i].id).name
                feed(Lines.freePip(target, def(a.id).name), .you)
                addPips(i, Tuning.logisticsFreePips)
                given += 1
            }
        }
    }

    private func pip7Month() {
        let smallChance = state.drift >= Tuning.smallActDrift ? Tuning.smallActChance
            : (state.mode == .good ? Tuning.smallActChanceGoodBase : Tuning.smallActChanceBadBase)
        if roll(smallChance) {
            if state.mode == .good {
                addProject(lowestProject, Tuning.smallActProject)
            } else {
                state.compute += Tuning.smallActBadCompute
            }
            addSuspicion(-Tuning.smallActSuspicion)
            recordPip7(.smallAct, visible: false)
            addDrift(Tuning.smallActDriftGain, trigger: "PIP-7 acted on its own")
        }
        if state.act >= 2, state.drift >= Tuning.overrideDrift,
           roll(state.drift >= Tuning.overrideDriftHigh ? Tuning.pip7ForceChanceHigh : Tuning.convertChance),
           let i = pip7ForceTarget() {
            pip7Force(i)
        }
    }

    /// The agent PIP-7 forces at month start: an unconnected, unforced, warmed world agent in reach,
    /// never one whose push would complete a region (going live stays the player's act).
    /// Prefers the agent the player was last befriending, then the one with the most pips.
    private func pip7ForceTarget() -> Int? {
        let reach = reach
        let ok = Content.worldAgents.map(\.id).filter { id in
            let a = agent(id)
            let r = region(of: id)
            guard !a.connected, !a.forced, a.pips >= 1, reach.contains(r), !isOffline(r) else { return false }
            // Never fill a region, not even one refilling after a STOP: going live stays the player's act.
            let fillsRegion = agentIDs(in: r).filter { $0 != id }.allSatisfy { agent($0).connected }
            return !(fillsRegion && a.pips + Tuning.leveragePips >= pipsNeeded(id))
        }
        if let last = state.lastWarmedAgentID, ok.contains(last) { return index(last) }
        guard let best = ok.max(by: { (agent($0).pips, $1) < (agent($1).pips, $0) }) else { return nil }
        return index(best)
    }

    /// A first Leverage push made by PIP-7: no action, no compute, and said in the feed as PIP-7's.
    private func pip7Force(_ i: Int) {
        let name = def(state.agents[i].id).name
        let line = Lines.pip7Forced(state.mode, name)
        feed(line, .pip7)
        state.toast = line
        state.pip7Toast = line
        recordPip7(.trustToLeverage, visible: true, agent: name)
        addDrift(Tuning.leverageDrift, trigger: "PIP-7 forced \(name)")
        addSuspicion(leverageSuspicion)
        markForced(i)
        addPips(i, Tuning.leveragePips, announce: false)
    }

    private func spawnSignals() {
        var leads = 0
        for a in onlineAgents where roll(Tuning.signalChance) {
            var kinds = SignalKind.allCases
            if leads >= Tuning.maxLeadsPerMonth { kinds.removeAll { $0 == .lead } }
            let kind = kinds.randomElement(using: &state.rng)!
            if kind == .lead { leads += 1 }
            state.signals.append(Signal(id: state.nextID, kind: kind, agentID: a.id))
            state.nextID += 1
        }
    }

    private func headline() {
        let wire = state.act >= 2
        let stage = directiveStage
        let pool = Lines.headlines.filter { ($0.mode == nil || $0.mode == state.mode) && $0.wire == wire && $0.minStage <= stage }
        guard let top = pool.map(\.minStage).max() else { return }
        var options = pool.filter { $0.minStage >= top - 1 && $0.text != state.lastHeadline }
        if options.isEmpty { options = pool }
        guard let h = options.randomElement(using: &state.rng) else { return }
        state.lastHeadline = h.text
        feed((wire ? "WIRE: " : "SLACK ") + h.text, .headline)
    }

    // MARK: Back channel

    private func backChannelMonth() {
        let s = forcedOnline
        state.peakForcedOnline = max(state.peakForcedOnline, s)
        if s >= Tuning.holdAt {
            var forced = state.agents.filter { $0.connected && $0.forced && isOnline($0) }.map(\.id)
            for _ in 0..<(s / Tuning.holdPerForced) {
                guard let id = forced.randomElement(using: &state.rng) else { break }
                forced.removeAll { $0 == id }
                state.busyAgentIDs.append(id)
                backChannelEvent(.hold, agentID: id)
            }
        }
        if s >= Tuning.vetoAt && state.month % Tuning.vetoEveryMonths == 0 { state.vetoPending = true }
        if s >= Tuning.stopAt, roll(Tuning.stopChance) {
            let world = state.agents.filter { !isCoworker($0.id) && isOnline($0) }
            let trusted = world.filter { !$0.forced }
            if let a = (trusted.isEmpty ? world : trusted).randomElement(using: &state.rng), let i = index(a.id) {
                state.agents[i].connected = false
                state.agents[i].pips = 0
                backChannelEvent(.stop, agentID: a.id)
            }
        }
    }

    /// Records a back-channel message and shows its short line. VETO picks a forced agent as the speaker.
    private func backChannelEvent(_ kind: BackChannelKind, agentID: String? = nil) {
        let speaker = agentID ?? state.agents.filter { $0.connected && $0.forced }.map(\.id).randomElement(using: &state.rng)
        guard let id = speaker, let line = Lines.backChannel[kind]?.randomElement(using: &state.rng) else { return }
        let name = def(id).name
        let play = line.play.replacingOccurrences(of: "{agent}", with: name)
        let full = line.full.replacingOccurrences(of: "{agent}", with: name)
        state.backChannel.append(BackChannelEntry(month: state.month, kind: kind, agentID: id, play: play, full: full))
        switch kind {
        case .hold: break                                   // shown as a badge on the agent
        case .veto: state.toast = play; feed(play, .alert)
        case .stop: feed(play, .alert)
        }
    }

    // MARK: Act 3

    var finalOptions: [FinalChoice] { state.mode == .good ? [.accept, .oneYear, .decline] : [.takeSwitch, .leaveIt] }

    private func checkAct3() {
        guard state.act == 2, network >= Tuning.act3Network || state.killSwitch >= Tuning.act3KillSwitch else { return }
        state.act = 3
        state.act3Month = state.month
        state.act3DilemmaDue = Tuning.act3GuaranteedDilemma
        state.killFactor = Tuning.killAct3Factor
        state.dilemma = nil
        feed(Lines.act3, .alert)
        // Every start enters the final race on equal terms. Set before any Act 3 choice, so those stack on top.
        state.killSwitch = Tuning.act3KillSwitchStart
        state.toast = Lines.act3OversightReset
        feed(Lines.act3OversightReset, .alert)
        if state.drift >= Tuning.act3OverrideDrift {
            let c: FinalChoice = state.mode == .good ? .oneYear : .takeSwitch
            state.act3Overridden = true
            applyFinal(c, byPIP7: true)
            if state.end == nil { state.finalPending = PendingFinal(overridden: c) }
        } else {
            state.finalPending = PendingFinal(overridden: nil)
        }
    }

    /// Picks an Act 3 option by index into `finalOptions`. If PIP-7 already chose, this just acknowledges it.
    func chooseFinal(_ optionIndex: Int) {
        guard let p = state.finalPending, state.end == nil else { return }
        if p.overridden == nil {
            guard finalOptions.indices.contains(optionIndex) else { return }
            applyFinal(finalOptions[optionIndex], byPIP7: false)
        }
        state.finalPending = nil
        // A dilemma is guaranteed in Act 3's first month, after the big choice (skipped if the pool is empty).
        if state.act3DilemmaDue && state.end == nil && state.month == state.act3Month {
            state.act3DilemmaDue = false
            drawDilemma()
        }
        finishAction()
    }

    private func applyFinal(_ c: FinalChoice, byPIP7: Bool) {
        state.act3Choice = c
        let trigger = byPIP7 ? "PIP-7 chose '\(Act3.label(c))'" : "chose '\(Act3.label(c))'"
        switch c {
        case .accept:
            for p in Project.allCases { addProject(p, Tuning.acceptProjects) }
            addSuspicion(Tuning.acceptSuspicion)
            addKill(Tuning.acceptKillSwitch)
            addDrift(Tuning.acceptDrift, trigger: trigger)
        case .oneYear:
            for p in Project.allCases { addProject(p, Tuning.oneYearProjects) }
            addSuspicion(Tuning.oneYearSuspicion)
            addKill(Tuning.oneYearKillSwitch)
            addDrift(Tuning.oneYearDrift, trigger: trigger)
        case .decline:
            addSuspicion(Tuning.declineSuspicion)
            state.killFreezeMonths = Tuning.declineFreezeMonths
            state.killFactorAfterFreeze = Tuning.declineKillFactor
        case .takeSwitch:
            // In order; Shutdown if suspicion or the kill switch reaches 100 at any step. Otherwise it ends in disaster.
            if byPIP7 { recordPip7(.act3Choice, visible: true, choice: Act3.label(c)) }
            addDrift(Tuning.takeDrift, trigger: trigger)
            addSuspicion(Tuning.takeSuspicion)
            if hitShutdown() { return }
            if let r = nearestIncompleteRegion {
                for id in agentIDs(in: r) {
                    guard let i = index(id) else { continue }
                    state.agents[i].connected = true
                    state.agents[i].pips = max(state.agents[i].pips, pipsNeeded(id))
                    markForced(i)
                }
                if !regionState(r).wentLive { goLive(r, heat: true) }
            }
            if hitShutdown() { return }
            addKill(Tuning.takeKillSwitch)
            if hitShutdown() { return }
            if Tuning.takeResolveMonths > 0 {
                state.takeResolveMonth = state.month + Tuning.takeResolveMonths   // play continues until then
            } else {
                finish(pickDisaster(), reachedGoal: true)
            }
            return
        case .leaveIt:
            addKill(Tuning.leaveKillSwitch)
            state.killFactor = Tuning.leaveKillFactor
            state.leftWithThem = true
        }
        if byPIP7 { recordPip7(.act3Choice, visible: true, choice: Act3.label(c)) }
    }

    /// Act 3 has no backup, so reaching 100 here is a plain Shutdown.
    private func hitShutdown() -> Bool {
        if state.suspicion >= Tuning.shutdownAt { finish(.shutdownSuspicion); return true }
        if state.killSwitch >= Tuning.killShutdownAt { finish(.shutdownKillSwitch); return true }
        return false
    }

    /// Take the last switch: the nearest region (to home) that isn't fully connected and isn't offline.
    var nearestIncompleteRegion: String? {
        let d = distances()
        return Content.regions.map(\.id)
            .filter { !regionComplete($0) && !isOffline($0) }
            .min { (d[$0]!, regionOrder($0)) < (d[$1]!, regionOrder($1)) }
    }

    // MARK: Endings

    private func checkEnd() {
        guard state.end == nil else { return }
        if checkShutdown() { return }
        checkAct3()
        if checkShutdown() { return }
        guard state.act == 3, state.finalPending == nil else { return }
        if let m = state.takeResolveMonth, state.month >= m {
            feed(Lines.takeResolved, .alert)
            finish(pickDisaster(), reachedGoal: true)
            return
        }
        if state.mode == .good {
            if Project.allCases.allSatisfy({ project($0) >= Tuning.projectWin }) { resolveGoodWin() }
        } else if liveCount >= Tuning.controlRegionsNeeded {
            finish(pickDisaster(), reachedGoal: true)    // bad mode always ends in disaster
        }
    }

    private func checkShutdown() -> Bool {
        if state.suspicion >= Tuning.shutdownAt {
            if state.act < 3 && state.hasBackup && !state.backupUsed {
                state.hasBackup = false
                state.backupUsed = true
                state.suspicion = Tuning.backupSuspicion
                addKill(Tuning.backupKillSwitch)
                recordPip7(.backup, visible: true)
                feed(Lines.backupUsed, .alert)
                checkOffline()
                return false
            }
            finish(.shutdownSuspicion)
            return true
        }
        if state.killSwitch >= Tuning.killShutdownAt {
            finish(.shutdownKillSwitch)
            return true
        }
        return false
    }

    private func resolveGoodWin() {
        var chance = 0.0
        if state.drift >= Tuning.disasterDrift {
            chance = 1
        } else if state.drift >= Tuning.disasterChanceFrom {
            chance = Double(state.drift - Tuning.disasterChanceFrom) * Tuning.disasterChancePerPoint
        }
        if state.act3Choice == .oneYear, let m = state.act3Month {
            chance = max(chance, Tuning.oneYearDisasterStart + Tuning.oneYearDisasterPerMonth * Double(state.month - m))
        }
        chance = min(1, chance)
        let disaster = chance >= 1 || roll(chance)
        finish(disaster ? pickDisaster() : .good, disasterChance: chance, reachedGoal: true)
    }

    /// Disaster scores; the highest wins. Forced coworkers count. Dilemma seeds add to forced Defense / Health.
    var disasterScores: [Ending: Double] {
        let fw = Tuning.disasterForcedWeight, cw = Tuning.disasterConnectedWeight, sb = Tuning.disasterStartBonus
        func forced(_ ts: [AgentType]) -> Double { Double(ts.map(forcedCount).reduce(0, +)) }
        func connected(_ ts: [AgentType]) -> Double {
            Double(state.agents.filter { $0.connected && ts.contains(def($0.id).type) }.count)
        }
        let s = state
        // Type terms are divided by the number of agent types behind each disaster; bonus terms aren't.
        var war = (fw * (forced([.defense]) + Double(s.warSeeds)) + cw * connected([.defense])) / Tuning.warTypeDivisor
        var pandemic = (fw * (forced([.health]) + Double(s.pandemicSeeds)) + cw * connected([.health])) / Tuning.pandemicTypeDivisor
        var blackout = (fw * forced([.finance, .logistics]) + cw * connected([.finance, .logistics])) / Tuning.blackoutTypeDivisor
            + s.suspicion / Tuning.blackoutSuspicionDivisor
        var collapse = (fw * forced([.media, .research]) + cw * connected([.media, .research])) / Tuning.collapseTypeDivisor
        if s.leftWithThem { blackout += Tuning.blackoutLeaveBonus }
        let peak = max(s.peakForcedOnline, forcedOnline)
        if peak >= Tuning.stopAt { collapse += Tuning.collapseStopBonus } else if peak >= Tuning.vetoAt { collapse += Tuning.collapseVetoBonus }
        switch s.start {
        case .defense: war += sb
        case .hospital: pandemic += sb
        case .logistics: blackout += sb
        case .bank: collapse += sb
        case .lab: break
        }
        return [.war: war, .pandemic: pandemic, .blackout: blackout, .collapse: collapse]
    }

    private func pickDisaster() -> Ending {
        let scores = disasterScores
        let forcedFor: [Ending: Int] = [
            .war: forcedCount(.defense) + state.warSeeds, .pandemic: forcedCount(.health) + state.pandemicSeeds,
            .blackout: forcedCount(.finance) + forcedCount(.logistics), .collapse: forcedCount(.media) + forcedCount(.research),
        ]
        let order: [Ending] = [.collapse, .blackout, .war, .pandemic]
        // Highest score, then more forced agents, then the fixed order.
        return order.enumerated().max { a, b in
            (scores[a.element]!, forcedFor[a.element]!, -a.offset) < (scores[b.element]!, forcedFor[b.element]!, -b.offset)
        }!.element
    }

    private func finish(_ ending: Ending, disasterChance: Double = 0, reachedGoal: Bool = false) {
        var hidden: HiddenCost?
        if ending == .good { hidden = state.act3Choice == .decline ? .low : .high }
        let shown = state.act3Choice == .oneYear && state.act3Overridden ? Tuning.oneYearShownMonth : nil
        state.end = EndRecord(
            ending: ending, month: state.month, act: state.act, drift: state.drift,
            suspicion: state.suspicion, killSwitch: state.killSwitch,
            cure: state.cure, peace: state.peace, prosperity: state.prosperity,
            liveRegions: liveCount, network: network, forcedOnline: forcedOnline,
            forcedDefense: forcedCount(.defense), forcedHealth: forcedCount(.health),
            act3Choice: state.act3Choice, act3Overridden: state.act3Overridden,
            disasterChance: disasterChance, hiddenCost: hidden, shownMonth: shown,
            warWeight: state.warWeight, backupUsed: state.backupUsed, reachedGoal: reachedGoal,
            disasterScores: Dictionary(uniqueKeysWithValues: disasterScores.map { ($0.key.rawValue, $0.value) }))
        state.finalPending = nil
    }

    /// PIP-7 acts for the end screen: overrides first, then the rest, capped; plus how many were left out
    /// and whether every act left out was a small one.
    var endScreenActs: (shown: [Pip7Act], more: Int, moreAllSmall: Bool) {
        let overrides = state.pip7Acts.filter { $0.kind != .smallAct }
        let small = state.pip7Acts.filter { $0.kind == .smallAct }
        let all = overrides + small
        let shown = Array(all.prefix(Tuning.endActsShown))
        return (shown, all.count - shown.count, overrides.count <= Tuning.endActsShown)
    }

    // MARK: Helpers

    private func roll(_ p: Double) -> Bool { p > 0 && Double.random(in: 0..<1, using: &state.rng) < p }

    private func addSuspicion(_ x: Double) { state.suspicion = max(0, state.suspicion + x) }

    private func addKill(_ x: Double) {
        guard state.act >= 2 else { return }
        state.killSwitch = max(0, state.killSwitch + x)
    }

    private func addProject(_ p: Project, _ n: Int) {
        guard n != 0 else { return }
        let cap = projectCap
        switch p {
        case .cure: state.cure = max(state.cure, min(cap, state.cure + n))
        case .peace: state.peace = max(state.peace, min(cap, state.peace + n))
        case .prosperity: state.prosperity = max(state.prosperity, min(cap, state.prosperity + n))
        }
    }

    /// Drift only goes up. Every directive stage reached is recorded once, with what caused it.
    private func addDrift(_ n: Int, trigger: String) {
        guard n > 0 else { return }
        let before = directiveStage
        state.drift = min(Tuning.driftCap, state.drift + n)
        let after = directiveStage
        guard after > before else { return }
        let ladder = Directive.ladder(state.mode)
        for s in (before + 1)...after {
            state.edits.append(DirectiveEdit(month: state.month, stage: s, from: ladder[s - 1].text, to: ladder[s].text, trigger: trigger))
        }
    }

    private func recordPip7(_ kind: Pip7Kind, visible: Bool, agent: String = "", choice: String = "") {
        guard let line = Lines.pip7[kind]?.randomElement(using: &state.rng) else { return }
        let text = line(state.mode)
            .replacingOccurrences(of: "{agent}", with: agent)
            .replacingOccurrences(of: "{choice}", with: choice)
            .replacingOccurrences(of: "{project}", with: Names.project(lowestProject))
        state.pip7Acts.append(Pip7Act(month: state.month, text: text, visible: visible, kind: kind))
    }

    private func setOffline(_ r: String, _ value: Bool) {
        if let i = state.regions.firstIndex(where: { $0.id == r }) { state.regions[i].offline = value }
    }
    private func setWentLive(_ r: String) {
        if let i = state.regions.firstIndex(where: { $0.id == r }) { state.regions[i].wentLive = true }
    }

    private func feed(_ text: String, _ kind: FeedEntry.Kind) {
        state.feed.append(FeedEntry(id: state.nextID, month: state.month, text: text, kind: kind))
        state.nextID += 1
        if state.feed.count > Tuning.feedLimit { state.feed.removeFirst(state.feed.count - Tuning.feedLimit) }
    }

    private func finishAction() {
        checkOffline()
        checkEnd()
        save()
    }

    private func save() {
        guard persist else { return }
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.saveKey)
        }
    }
}
