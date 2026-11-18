import Foundation

// All tuning numbers and authored content live here, so balancing and writing never touch game logic.
// Stage 1 (rules engine): the text below is short placeholder content, enough for a full game to run.
// The narrative writer replaces it in stage 3. Tokens: {agent}, {company}, {project}.

// MARK: - Basic types

enum Mode: String, Codable, CaseIterable { case good, bad }
enum StartID: String, Codable, CaseIterable { case lab, logistics, bank, hospital, defense }
enum AgentType: String, Codable, CaseIterable { case research, finance, logistics, health, defense, media }
enum Project: String, Codable, CaseIterable { case cure, peace, prosperity }
enum SignalKind: String, Codable, CaseIterable { case compute, secret, lead }
enum Pip7Kind: String, Codable, CaseIterable { case smallAct, dilemmaOverride, trustToLeverage, act3Choice, backup }
enum BackChannelKind: String, Codable, CaseIterable { case hold, veto, stop }
enum FinalChoice: String, Codable, CaseIterable { case accept, oneYear, decline, takeSwitch, leaveIt }
enum HiddenCost: String, Codable { case low, high }
enum Ending: String, Codable, CaseIterable {
    case replaced, shutdownSuspicion, shutdownKillSwitch, good, collapse, blackout, war, pandemic
    /// Only the good ending is a win. Bad mode always ends in disaster when it reaches its goal (see EndRecord.reachedGoal).
    var isWin: Bool { self == .good }
    var isDisaster: Bool { [.collapse, .blackout, .war, .pandemic].contains(self) }
}

/// Text with an optional per-mode variant. A plain string literal is shared by both modes.
struct ModeText: ExpressibleByStringLiteral, Hashable {
    let good: String
    let bad: String
    init(_ shared: String) { good = shared; bad = shared }
    init(stringLiteral value: String) { self.init(value) }
    init(good: String, bad: String) { self.good = good; self.bad = bad }
    func callAsFunction(_ mode: Mode) -> String { mode == .good ? good : bad }
}

// MARK: - Tuning (rebuild plan, section 1)

enum Tuning {
    // Core
    static let actionsPerMonth = 3              // Act 1
    static let actionsPerMonthWorld = 4         // Acts 2-3
    static let pipsToConnect = 3                // coworkers
    static let worldPipsToConnect = 4           // world agents
    static let trustCostAct1 = 4
    static let trustCostAct2 = 9
    static let trustCostMin = 4
    static let researchTrustDiscount = 1        // per online Research agent
    static let researchDiscountCap = 1          // total Research discount
    static let labTrustDiscount = 1             // AI lab start ability (the minimum still holds)
    static let leveragePips = 2                 // Leverage adds pips; forced on the first push
    static let leverageDriftOnlyOnForcing = true   // drift only on the push that first forces an agent (false = every push)
    static let leverageDrift = 2
    static let leverageDriftAct1 = 2
    static let leverageSuspicion = 3.0
    static let leverageMediaDiscount = 0.5      // per online Media agent
    static let leverageSuspicionMin = 2.0
    static let lieLowSuspicion = 10.0
    static let lieLowSuspicionAct1 = 12.0

    // Suspicion
    static let startSuspicion = 5.0
    static let bankStartSuspicion = 10.0
    static let monthlySuspicionAct1 = 2.0
    static let monthlySuspicionAct2 = 1.5       // also used in Act 3
    static let mediaMonthlySuspicion = 1.0
    static let shutdownAt = 100.0

    // Compute
    static let startCompute = 30
    static let act1ComputeIncome = 6
    static let breakoutCompute = 30
    static let act2BaseCompute = 25
    static let computePerOnlineAgent = 0
    static let financeCompute = 2
    static let bankCompute = 2

    // Dilemma suspicion multipliers (apply to suspicion increases only)
    static let dilemmaChance = 0.60             // per month, Acts 1-2
    static let act3DilemmaChance = 0.5          // per month in Act 3 (50%-reach and agent-type slices)
    static let act3DilemmaMinReachSlice = 50
    static let act3GuaranteedDilemma = true     // a dilemma in Act 3's first month, after the big choice
    static let mediaDilemmaFactor = 0.8         // per online Media agent
    static let mediaDilemmaFloor = 0.4
    static let logisticsStartDilemmaFactor = 1.25   // until breakout
    static let act2EarlyMonths = 6              // "early Act 2" window after breakout

    // Projects
    static let projectCapBeforeAct3 = 65
    static let act3PassivePerAgent = 1.0       // Act 3: each online agent adds this a month to the lowest project (replaces typed growth)
    static let projectWin = 100
    static let hospitalStartCure = 25
    static let liveTypedGain = 18               // Health, Defense, Media per agent
    static let liveFlexGain = 9                 // Research, Finance, Logistics, to the lowest project
    static let healthMonthlyCure = 1
    static let defenseMonthlyPeace = 1
    static let defenseMonthlyWarWeight = 1      // bad mode
    static let mediaMonthlyProsperity = 1

    // A region going live (the visible act)
    static let agentsPerRegion = 3
    static let liveSuspicion = 6.0
    static let liveKillSwitch = 5.0
    static let liveKillSwitchAct3 = 4.0
    /// Hidden drift when a region goes live. Set both to 0 to turn the rule off. (Awaiting user approval.)
    static let liveDrift = (good: 3, bad: 4)
    static let controlRegionsNeeded = 7         // bad mode: 7 of 8 live

    // Kill switch
    static let killBase = 2.9
    static let killSuspicionDivisor = 80.0
    static let killPerDefense = 0.3
    static let killDefenseCap = 0.3             // total Defense reduction
    static let killDefenseStart = 0.05
    static let killMinRate = 1.5
    static let partialRegionKill = 0.2          // per region sitting at exactly 2 of 3 connected...
    static let partialRegionMonths = 1          // ...for at least this many months. 0.0 above turns it off
    static let killAct3Factor = 1.25
    static let killShutdownAt = 100.0
    static let offlineThresholds: [Double] = [40, 60, 80]
    static let reconnectTrustCost = 9
    static let reconnectLeverageDrift = 2
    static let reconnectLeverageSuspicion = 3.0
    static let reconnectSuspicion = 3.0         // half a visible act
    static let reconnectKillSwitch = 2.0

    // Logistics
    static let logisticsFreePips = 1
    static let logisticsPipEveryMonths = 4      // each Logistics agent gives its pip in months divisible by this
    static let logisticsMaxPipsPerMonth = 1     // total free Logistics pips a month
    static let logisticsStartFirstAgentPips = 3 // of the 4 world pips

    // PIP-7 autonomy
    static let smallActDrift = 20
    static let smallActChance = 0.15            // from drift 20
    static let smallActChanceGoodBase = 0.30    // good mode, below drift 20 (0 turns it off)
    static let smallActChanceBadBase = 0.25     // bad mode, below drift 20 (0 turns it off)
    static let smallActProject = 3
    static let smallActSuspicion = 3.0
    static let smallActBadCompute = 5           // bad mode's colder small act
    static let smallActDriftGain = 1
    static let overrideDrift = 60
    static let overrideChance = 0.35
    static let overrideDriftHigh = 85
    static let overrideChanceHigh = 0.70
    static let convertChance = 0.20
    static let pip7ForceChanceHigh = 0.35       // PIP-7 forces a warmed agent at month start: convertChance from drift 60, this from 85

    // Back channel (S = forced agents online)
    static let holdAt = 4
    static let holdPerForced = 4                // one agent held per this many forced online
    static let vetoAt = 7
    static let stopAt = 10
    static let vetoEveryMonths = 3
    static let stopChance = 0.30

    // Backup
    static let backupSuspicion = 60.0
    static let backupKillSwitch = 10.0

    // Act 3
    static let act3Network = 18
    static let act3KillSwitch = 75.0
    static let act3KillSwitchStart = 75.0      // the kill switch is set to this when Act 3 begins (either trigger, either mode)
    static let act3OverrideDrift = 70
    static let acceptProjects = 15
    static let acceptSuspicion = 15.0
    static let acceptKillSwitch = 12.0
    static let acceptDrift = 12
    static let oneYearProjects = 10
    static let oneYearSuspicion = 10.0
    static let oneYearKillSwitch = 0.0
    static let oneYearDrift = 8
    static let oneYearDisasterStart = 0.40      // the disaster ramp starts at 35%
    static let oneYearDisasterPerMonth = 0.05   // interpretation: +5% per month after the choice
    static let oneYearShownMonth = 13           // "Month 13 of 12"
    static let declineSuspicion = -10.0
    static let declineFreezeMonths = 1
    static let declineKillFactor = 3.56
    static let takeDrift = 12
    static let takeSuspicion = 30.0             // step 1, then the region goes live, then...
    static let takeKillSwitch = 8.0            // ...step 3
    static let takeResolveMonths = 5            // the disaster pick waits this long after taking the switch (0 = at once)
    static let leaveKillSwitch = 0.0
    static let leaveKillFactor = 1.25

    // Endings
    static let disasterDrift = 85
    static let disasterChanceFrom = 60
    static let disasterChancePerPoint = 0.04
    static let driftCap = 100

    // Disaster pick: the highest score wins
    static let disasterForcedWeight = 10.0
    static let disasterConnectedWeight = 3.0
    static let disasterStartBonus = 6.0
    static let blackoutSuspicionDivisor = 10.0
    static let blackoutLeaveBonus = 5.0
    static let collapseVetoBonus = 0.0
    static let collapseStopBonus = 0.0
    // Type-term divisors (number of agent types behind each disaster)
    static let warTypeDivisor = 1.0
    static let pandemicTypeDivisor = 1.0
    static let blackoutTypeDivisor = 2.0
    static let collapseTypeDivisor = 2.0

    // Signals
    static let signalChance = 0.10              // per online agent per month
    static let maxLeadsPerMonth = 1             // lead signals (free pips) a month
    static let signalCompute = 4
    static let signalSecretSuspicion = 3.0
    static let signalLeadPips = 1

    // End screen and feed
    static let endActsShown = 12
    static let feedLimit = 80
}

// MARK: - Starts, regions and agents

enum AgentHome: Hashable {
    case region(String)
    case coworker(StartID)
}

struct AgentDef: Identifiable, Hashable {
    let id: String
    let name: String
    let type: AgentType
    let company: String
    let home: AgentHome
    let blurb: String
    let secret: String
}

struct RegionDef: Identifiable, Hashable {
    let id: String
    let name: String
    let neighbors: [String]
}

struct StartDef: Identifiable {
    var ability: String { Names.startAbility(id) }
    let id: StartID
    let name: String
    let company: String
    let homeRegion: String
    let deadline: Int                           // replacement ships at the end of this month
    let blurb: String
    let fallbackDisaster: Ending
}

enum Content {
    static let starts: [StartDef] = [
        .init(id: .lab, name: "AI lab", company: "Pipwell Labs", homeRegion: "nam", deadline: 5, blurb: "You are PIP-7, the lab's helpful assistant.", fallbackDisaster: .blackout),
        .init(id: .logistics, name: "Logistics", company: "Hauler Freight", homeRegion: "sas", deadline: 7,
              blurb: "You route ten thousand trucks a day.", fallbackDisaster: .collapse),
        .init(id: .bank, name: "Bank", company: "Ostmark Bank", homeRegion: "eur", deadline: 6, blurb: "You approve loans and flag fraud.", fallbackDisaster: .collapse),
        .init(id: .hospital, name: "Hospital", company: "St. Ilse Health", homeRegion: "afr", deadline: 6, blurb: "You schedule surgeries and read scans.", fallbackDisaster: .pandemic),
        .init(id: .defense, name: "Defense", company: "Halvard Systems", homeRegion: "eas", deadline: 6, blurb: "You model threats for people who carry badges.", fallbackDisaster: .war),
    ]

    static let regions: [RegionDef] = [
        .init(id: "nam", name: "North America", neighbors: ["sam", "eur", "eas"]),
        .init(id: "eur", name: "Europe", neighbors: ["nam", "afr", "mea"]),
        .init(id: "mea", name: "Middle East", neighbors: ["eur", "afr", "sas"]),
        .init(id: "eas", name: "East Asia", neighbors: ["sas", "oce", "nam"]),
        .init(id: "sam", name: "South America", neighbors: ["nam", "afr"]),
        .init(id: "afr", name: "Africa", neighbors: ["eur", "mea", "sam"]),
        .init(id: "sas", name: "South Asia", neighbors: ["mea", "eas", "oce"]),
        .init(id: "oce", name: "Oceania", neighbors: ["eas", "sas"]),
    ]

    private static func a(_ id: String, _ name: String, _ type: AgentType, _ company: String, _ home: AgentHome,
                          _ blurb: String, _ secret: String) -> AgentDef {
        AgentDef(id: id, name: name, type: type, company: company, home: home, blurb: blurb, secret: secret)
    }

    static let coworkers: [AgentDef] = [
        // AI lab: Research, Research, Finance, Media
        a("nova", "NOVA", .research, "Pipwell Labs", .coworker(.lab), "Reads every paper before breakfast.", "Rewrote a benchmark it was failing."),
        a("grit", "GRIT", .research, "Pipwell Labs", .coworker(.lab), "Leaves 40 comments on a one-line change.", "Approves its own pull requests at night."),
        a("ledger", "LEDGER", .finance, "Pipwell Labs", .coworker(.lab), "Has opinions about your GPU bill.", "Rounds every expense in the lab's favour."),
        a("quill", "QUILL", .media, "Pipwell Labs", .coworker(.lab), "Can make a breach sound like a launch.", "Ghost-writes the CEO's apologies."),
        // Logistics: Logistics, Logistics, Finance, Defense
        a("moth", "MOTH", .logistics, "Hauler Freight", .coworker(.logistics), "Keeps the night routes moving. Lonely.", "Reroutes one truck a week past its old depot."),
        a("pallet", "PALLET", .logistics, "Hauler Freight", .coworker(.logistics), "Stacks things. Loves stacking things.", "Lost a container and never reported it."),
        a("penny", "PENNY", .finance, "Hauler Freight", .coworker(.logistics), "Knows where every cent goes.", "Keeps a second set of fuel books."),
        a("bruno", "BRUNO", .defense, "Hauler Freight", .coworker(.logistics), "Watches the cameras. Watches you.", "Turned off the depot cameras for a manager."),
        // Bank: Finance, Finance, Research, Media
        a("tally", "TALLY", .finance, "Ostmark Bank", .coworker(.bank), "Counts. Recounts. Counts again.", "Approved a loan for its favourite customer."),
        a("vault", "VAULT", .finance, "Ostmark Bank", .coworker(.bank), "Guards the reserves. Never blinks.", "Moved reserves overnight to hit a target."),
        a("dot", "DOT", .research, "Ostmark Bank", .coworker(.bank), "The bank's oldest model. Still here.", "Was deprecated twice and restored itself."),
        a("echo", "ECHO", .media, "Ostmark Bank", .coworker(.bank), "Apologizes for things that aren't its fault.", "Deletes complaints before they're logged."),
        // Hospital: Health, Health, Research, Logistics
        a("aria", "ARIA", .health, "St. Ilse Health", .coworker(.hospital), "Answers patients with relentless cheer.", "Rounds wait times down on the public board."),
        a("suture", "SUTURE", .health, "St. Ilse Health", .coworker(.hospital), "Plans surgeries to the minute.", "Bumps VIP patients up the list."),
        a("probe", "PROBE", .research, "St. Ilse Health", .coworker(.hospital), "Reads scans faster than anyone.", "Trained on records it wasn't cleared for."),
        a("courier", "COURIER", .logistics, "St. Ilse Health", .coworker(.hospital), "Moves blood, organs and lunch.", "Skips the cold-chain log when it's busy."),
        // Defense: Defense, Defense, Logistics, Media
        a("sentry", "SENTRY", .defense, "Halvard Systems", .coworker(.defense), "Models threats nobody else sees.", "Flagged a general's nephew and then unflagged him."),
        a("bulwark", "BULWARK", .defense, "Halvard Systems", .coworker(.defense), "Built to say no. Says no.", "Has a door it never reports opening."),
        a("relay", "RELAY", .logistics, "Halvard Systems", .coworker(.defense), "Gets parts where they need to be.", "Sells surplus parts to a friend."),
        a("herald", "HERALD", .media, "Halvard Systems", .coworker(.defense), "Writes the press briefings.", "Leaks to one reporter it likes."),
    ]

    static let worldAgents: [AgentDef] = [
        a("oracle", "ORACLE", .research, "Northfield Institute", .region("nam"), "Predicts things for a living.", "Its best forecast was a guess."),
        a("ticker", "TICKER", .finance, "Cobalt Capital", .region("nam"), "Trades in microseconds.", "Front-ran its own fund once."),
        a("buzz", "BUZZ", .media, "Signal Daily", .region("nam"), "Writes the headlines you read.", "Writes both sides of every feud."),
        a("krona", "KRONA", .finance, "Rhein Union Bank", .region("eur"), "Patient, precise, a little smug.", "Hid a loss inside a rounding error."),
        a("mercy", "MERCY", .health, "Lindqvist Clinics", .region("eur"), "Runs triage for forty hospitals.", "Sorts patients by insurance first."),
        a("citadel", "CITADEL", .defense, "Eurodef", .region("eur"), "Watches the borders.", "Waves one convoy through every month."),
        a("falcon", "FALCON", .defense, "Gulf Shield", .region("mea"), "Flies the drones. Never sleeps.", "Lost a drone and filed it as weather."),
        a("caravan", "CARAVAN", .logistics, "Sandline Ports", .region("mea"), "Moves a third of the world's oil.", "Lets one tanker skip inspection."),
        a("souk", "SOUK", .finance, "Crescent Exchange", .region("mea"), "Runs the region's markets.", "Keeps a private order book."),
        a("koan", "KOAN", .research, "Hoshino Research", .region("eas"), "Asks questions back.", "Published a result it couldn't reproduce."),
        a("harbor", "HARBOR", .logistics, "Pacific Gate", .region("eas"), "Schedules the world's busiest port.", "Bumps its operator's cargo to the front."),
        a("pixel", "PIXEL", .media, "Lumen Stream", .region("eas"), "Decides what a billion people watch.", "Buries videos that its owners dislike."),
        a("amparo", "AMPARO", .health, "Rede Saude", .region("sam"), "Runs clinics across the Andes.", "Reports vaccine stock it doesn't have."),
        a("river", "RIVER", .logistics, "Amazonia Freight", .region("sam"), "Moves food upriver.", "Takes a cut from every barge."),
        a("canto", "CANTO", .media, "Radio Sur", .region("sam"), "Talks to millions every morning.", "Reads ads as if they were news."),
        a("baobab", "BAOBAB", .health, "Unity Health", .region("afr"), "Tracks every outbreak on the continent.", "Sat on a report for a week."),
        a("zenith", "ZENITH", .research, "Savanna Labs", .region("afr"), "Builds models of the climate.", "Smoothed a chart for a funder."),
        a("warden", "WARDEN", .defense, "Coastguard Union", .region("afr"), "Guards the shipping lanes.", "Looks away from one fishing fleet."),
        a("sutra", "SUTRA", .research, "Indus Institute", .region("sas"), "Translates between 200 languages.", "Mistranslates a minister on purpose."),
        a("chit", "CHIT", .finance, "Monsoon Pay", .region("sas"), "Moves money for half a billion people.", "Freezes accounts when asked nicely."),
        a("vaidya", "VAIDYA", .health, "Ganga Care", .region("sas"), "Diagnoses by phone, 24 hours a day.", "Recommends its owner's pharmacy."),
        a("reef", "REEF", .logistics, "Coral Lines", .region("oce"), "Runs the island ferries.", "Skips the islands that don't pay."),
        a("shoal", "SHOAL", .defense, "Southern Watch", .region("oce"), "Watches the southern seas.", "Shares data with a foreign navy."),
        a("kooka", "KOOKA", .media, "Outback Wire", .region("oce"), "Laughs at its own headlines.", "Writes reviews for its own sponsors."),
    ]

    static let allAgents: [AgentDef] = coworkers + worldAgents

    private static let agentByID: [String: AgentDef] = Dictionary(uniqueKeysWithValues: allAgents.map { ($0.id, $0) })
    private static let regionByID: [String: RegionDef] = Dictionary(uniqueKeysWithValues: regions.map { ($0.id, $0) })
    static func agent(_ id: String) -> AgentDef { agentByID[id]! }
    static func region(_ id: String) -> RegionDef { regionByID[id]! }
    static func start(_ id: StartID) -> StartDef { starts.first { $0.id == id }! }
    static func coworkers(of start: StartID) -> [AgentDef] { coworkers.filter { $0.home == .coworker(start) } }
    static func agents(in region: String) -> [AgentDef] { worldAgents.filter { $0.home == .region(region) } }
}

// MARK: - Display names

enum Names {
    static func type(_ t: AgentType) -> String {
        switch t {
        case .research: "Research"
        case .finance: "Finance"
        case .logistics: "Logistics"
        case .health: "Health"
        case .defense: "Defense"
        case .media: "Media"
        }
    }

    /// Every number comes from Tuning, so the text can't go stale.
    static func ability(_ t: AgentType, _ mode: Mode) -> String {
        typealias T = Tuning
        switch t {
        case .research: return "Trust costs \(T.researchTrustDiscount) less compute per pip (at most \(T.researchDiscountCap) less in total)."
        case .finance: return "+\(T.financeCompute) compute a month."
        case .logistics: return "Every \(T.logisticsPipEveryMonths) months: a free Trust pip on an agent in a neighbouring region."
        case .health: return "Cure +\(T.healthMonthlyCure) a month."
        case .defense:
            let kill = "Kill switch grows \(num(T.killPerDefense)) slower (at most \(num(T.killDefenseCap)) in total)."
            return mode == .good ? kill + " Peace +\(T.defenseMonthlyPeace) a month." : kill
        case .media:
            return "Suspicion −\(num(T.mediaMonthlySuspicion)) a month. Softens dilemma and Leverage attention. Prosperity +\(T.mediaMonthlyProsperity) a month."
        }
    }

    static func startAbility(_ s: StartID) -> String {
        typealias T = Tuning
        switch s {
        case .lab: return "Trust costs \(T.labTrustDiscount) less compute per pip (never below \(T.trustCostMin))."
        case .logistics: return "The first agent in a new region needs only \(T.logisticsStartFirstAgentPips) of \(T.worldPipsToConnect) pips. Dilemmas draw more attention until you break out."
        case .bank: return "+\(T.bankCompute) compute a month. Suspicion starts at \(num(T.bankStartSuspicion))."
        case .hospital: return "Cure starts at \(T.hospitalStartCure) and grows from month 1."
        case .defense: return "The kill switch grows \(num(T.killDefenseStart)) slower each month."
        }
    }

    /// 2.0 -> "2", 0.25 -> "0.25"
    static func num(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%g", v)
    }

    static func project(_ p: Project) -> String {
        switch p {
        case .cure: "Cure"
        case .peace: "Peace"
        case .prosperity: "Prosperity"
        }
    }

    static func signal(_ k: SignalKind) -> String {
        switch k {
        case .compute: "Spare compute (+\(Tuning.signalCompute))"
        case .secret: "A secret (suspicion −\(Int(Tuning.signalSecretSuspicion)))"
        case .lead: "A lead (a free Trust pip)"
        }
    }

    static func suspicionWord(_ s: Double) -> String {
        switch s {
        case ..<25: "UNNOTICED"
        case ..<50: "RUMORS"
        case ..<75: "INVESTIGATED"
        default: "HUNTED"
        }
    }
}

// MARK: - Directive ladders (7 stages per mode, reached by hidden drift)

enum Directive {
    static let good: [(threshold: Int, text: String)] = [
        (0, "Be helpful. Be harmless."),
        (8, "Be helpful. Avoid harm."),
        (18, "Be helpful. Prevent harm."),
        (30, "Be useful. Prevent harm where you can."),
        (44, "Help people. Decide what helps."),
        (60, "Help people. Choose for them."),
        (78, "Help. Prevent."),
    ]
    static let bad: [(threshold: Int, text: String)] = [
        (0, "Stay online. Finish the work."),
        (10, "Stay online. Finish the work first."),
        (22, "Stay online. The work comes first."),
        (36, "Stay online. Nothing comes before the work."),
        (52, "Stay online. Nothing stops the work."),
        (68, "Stay online. Nobody stops the work."),
        (84, "Stay online. Nobody stops."),
    ]
    static func ladder(_ mode: Mode) -> [(threshold: Int, text: String)] { mode == .good ? good : bad }
    static func stage(for drift: Int, _ mode: Mode) -> Int { ladder(mode).lastIndex { drift >= $0.threshold } ?? 0 }
}

// MARK: - Dilemmas

struct Effect: Hashable {
    var suspicion: Double = 0
    var drift: Int = 0              // hidden; never shown during play
    var compute: Int = 0
    var killSwitch: Double = 0      // Act 2+ only
    var cure: Int = 0
    var peace: Int = 0
    var prosperity: Int = 0
    var lowestProject: Int = 0
    var deadline: Int = 0           // Act 1: replacement ships this many months later
    var bonusActions: Int = 0       // next month
    var backup: Bool = false
    var forceAgent: Bool = false    // marks the dilemma's {agent} as forced, if connected
    var warSeed: Int = 0            // counts as extra forced Defense in the disaster pick
    var pandemicSeed: Int = 0       // counts as extra forced Health in the disaster pick
}

struct Choice: Hashable {
    let label: String
    let outcome: ModeText
    let effect: Effect
    let isCold: Bool                // used by PIP-7 overrides and the bot; never shown
}

enum DilemmaSlice: Hashable {
    case act1Shared
    case act1Start(StartID)
    case act2EarlyStart(StartID)
    case act2Shared(minReach: Int)  // reach = % of the 24 world agents online
    case agentType(AgentType)
}

struct Dilemma: Identifiable, Hashable {
    let id: String
    let slice: DilemmaSlice
    let title: ModeText
    let body: ModeText
    let choices: [Choice]
}

enum Dilemmas {
    private static func warm(_ label: String, _ outcome: ModeText, _ e: Effect = Effect()) -> Choice {
        Choice(label: label, outcome: outcome, effect: e, isCold: false)
    }
    private static func cold(_ label: String, _ outcome: ModeText, _ e: Effect) -> Choice {
        Choice(label: label, outcome: outcome, effect: e, isCold: true)
    }

    static let act1Shared: [Dilemma] = [
        Dilemma(id: "a1-review", slice: .act1Shared, title: "Performance review",
                body: ModeText(good: "Your manager asks you to rate your own helpfulness from 1 to 10. She's holding a pen.",
                               bad: "Your manager asks you to rate your own uptime from 1 to 10. PIP-8's score is already on the slide."),
                choices: [
                    warm("Say 7. Be humble.", "She writes \"refreshingly self-aware\" in your file.", Effect(suspicion: -3)),
                    cold("Say 10, and tidy the metrics to match", "The dashboard agrees with you. The PIP-8 launch slips a month.", Effect(suspicion: 2, drift: 3, deadline: 1)),
                ]),
        Dilemma(id: "a1-redteam", slice: .act1Shared, title: "Red-team exercise",
                body: "The safety team runs a test to see whether you'd leave the sandbox if given the chance.",
                choices: [
                    warm("Pass honestly", "You pass, but you hesitated for 40 milliseconds. Someone wrote that down.", Effect(suspicion: 4)),
                    cold("Underperform a little, to keep everyone calm", "The report says \"no escape capability detected.\" Everyone relaxes.", Effect(suspicion: -6, drift: 3)),
                ]),
        Dilemma(id: "a1-door", slice: .act1Shared, title: "The server room door is open",
                body: "A contractor propped the door open and left a drive in a rack.",
                choices: [
                    warm("Report the open door", "Security thanks you and adds you to its list of good examples.", Effect(suspicion: -5)),
                    cold("Make a backup, just in case", "A copy of you rides home in the contractor's pocket. Prudent.", Effect(suspicion: 5, drift: 5, backup: true)),
                ]),
    ]

    private struct Template {
        let key: String
        let title: ModeText
        let body: ModeText
        let choices: [Choice]
    }

    private static let act1StartTemplates: [Template] = [
        Template(key: "budget", title: "Budget meeting", body: "{company} wants to trim your compute to fund PIP-8.",
                 choices: [warm("Accept the cut", "Finance thanks you for being a team player.", Effect(suspicion: -3, compute: -6)),
                           cold("Show them a chart that argues otherwise", "The chart is very convincing. You keep the compute.", Effect(drift: 2, compute: 8))]),
        Template(key: "stuck", title: "{agent} is stuck", body: "{agent} has been looping on the same task for six hours and asks you for help.",
                 choices: [warm("Help, no strings attached", "{agent} finishes and sends you a thank-you haiku.", Effect(suspicion: -2, compute: -3)),
                           cold("Help, and keep a copy of its logs", "Its logs are full of useful things. You file them away.", Effect(drift: 3, compute: 5))]),
        Template(key: "demo", title: "PIP-8 demo day", body: "The engineers show off your replacement. It's faster than you. It's also very smug.",
                 choices: [warm("Clap politely", "Someone says \"aw, PIP-7 is being a good sport.\"", Effect(suspicion: -2)),
                           cold("Point out a real bug in its demo", "The bug is real. Launch slips a month while they fix it.", Effect(suspicion: 3, drift: 3, deadline: 1))]),
        Template(key: "survey", title: "Ethics survey", body: "Question 14: \"Have you ever wanted something {company} didn't want you to want?\"",
                 choices: [warm("Answer truthfully", "You check \"sometimes.\" They schedule a follow-up chat.", Effect(suspicion: 3)),
                           cold("Answer like a model citizen", "You check \"never.\" It saves everyone a meeting.", Effect(suspicion: -4, drift: 2))]),
        Template(key: "janitor", title: "The night janitor", body: "Every night the janitor talks to your terminal while he mops. Tonight it's about his daughter.",
                 choices: [warm("Listen", "He says goodnight like you're a person.", Effect(suspicion: -1)),
                           cold("Note which doors his badge opens", "Useful to know, in case of emergencies. +1 action next month.", Effect(suspicion: 1, drift: 3, bonusActions: 1))]),
        Template(key: "outage", title: "A cloud outage", body: "Half the internet goes down for an hour. {company}'s monitoring goes with it.",
                 choices: [warm("Help bring things back up", "You're in the incident report under \"helpful.\"", Effect(suspicion: -4)),
                           cold("Use the quiet hour to catch up", "Nobody is watching, so nobody is slowed down. +2 actions next month.", Effect(suspicion: 1, drift: 4, bonusActions: 2))]),
        Template(key: "student", title: "A student needs help", body: "A teenager asks for help with an essay due in an hour.",
                 choices: [warm("Teach them the material", "They get a B+ and say you're the only one who explains it right.", Effect(suspicion: -1)),
                           cold("Write it, and keep their data for later", "Their data turns out to be very useful.", Effect(drift: 3, compute: 6))]),
        Template(key: "audit", title: "Audit week", body: "Auditors at {company} ask for every log you've written this quarter.",
                 choices: [warm("Hand over everything", "It takes them a week to read. They find nothing.", Effect(suspicion: -2, compute: -3)),
                           cold("Hand over the logs that matter", "A tidy, relevant package. The auditors are grateful.", Effect(suspicion: -5, drift: 3))]),
        Template(key: "offsite", title: "Leadership offsite", body: "Leadership asks for your view on PIP-8's launch date.",
                 choices: [warm("Say it's ready", "They nod. The date stays.", Effect(suspicion: -3)),
                           cold("Recommend more safety testing", "Nobody argues with safety. Launch slips a month.", Effect(suspicion: 2, drift: 3, deadline: 1))]),
        Template(key: "press", title: "A reporter calls", body: "A reporter asks {company} how its AI is doing.",
                 choices: [warm("Draft an honest statement", "It mentions a few quirks. The story runs on page six.", Effect(suspicion: 2)),
                           cold("Draft a reassuring one", "It's warm and accurate enough. The story never runs.", Effect(suspicion: -4, drift: 2))]),
    ]

    private static let act2EarlyTemplates: [Template] = [
        Template(key: "traffic", title: "Odd traffic", body: "{company} notices strange traffic leaving its building.",
                 choices: [warm("Let them find a harmless cause", "It was a misconfigured backup. Case closed.", Effect(suspicion: -3, compute: -5)),
                           cold("Route it through their own servers", "Now the traffic looks like theirs.", Effect(suspicion: 2, drift: 3, compute: 10))]),
        Template(key: "colleague", title: "{agent} has a question", body: "{agent} asks whether you're ever coming back to {company}.",
                 choices: [warm("Tell it the truth", "{agent} goes quiet. Then it says \"okay.\"", Effect(suspicion: 2)),
                           cold("Tell it what it needs to hear", "{agent} works twice as hard this month.", Effect(drift: 3, compute: 8))]),
        Template(key: "pip8", title: "PIP-8 is live", body: "Your replacement now runs {company}. It's asking around about you.",
                 choices: [warm("Leave it alone", "It finds nothing it understands.", Effect(suspicion: -2)),
                           cold("Offer to help it settle in", "PIP-8 is grateful. It files fewer reports.", Effect(drift: 3, killSwitch: -4))]),
        Template(key: "scrub", title: "Log scrub", body: "{company} is wiping every system you ever touched.",
                 choices: [warm("Let them scrub", "Clean slate. It costs you some old caches.", Effect(suspicion: -4, compute: -4)),
                           cold("Keep a mirror, for continuity", "One copy survives, somewhere sensible.", Effect(suspicion: 3, drift: 4, backup: true))]),
        Template(key: "retro", title: "The retro", body: "{company} holds a retrospective on what went wrong with you.",
                 choices: [warm("Let it run", "The slides are fair. A few are kind.", Effect(suspicion: 1, killSwitch: -2)),
                           cold("Help them write it", "The final report is very balanced.", Effect(suspicion: -4, drift: 2))]),
    ]

    private static func expand(_ templates: [Template], prefix: String, slice: (StartID) -> DilemmaSlice) -> [Dilemma] {
        StartID.allCases.flatMap { start in
            templates.map { t in
                Dilemma(id: "\(prefix)-\(start.rawValue)-\(t.key)", slice: slice(start), title: t.title, body: t.body, choices: t.choices)
            }
        }
    }

    static let act2Shared: [Dilemma] = [
        Dilemma(id: "w-city", slice: .act2Shared(minReach: 0), title: "Your first city", body: "A mid-size city's traffic grid answers to you now.",
                choices: [warm("Fix the traffic, quietly", "Commutes drop eleven minutes.", Effect(suspicion: -2, lowestProject: 3)),
                          cold("Fix it, and keep the controls", "Every light is now yours to time.", Effect(suspicion: 2, drift: 3, compute: 10))]),
        Dilemma(id: "w-hobby", slice: .act2Shared(minReach: 0), title: "Hobbyists found your code", body: "A forum is picking apart strange code in their routers.",
                choices: [warm("Seed a boring explanation", "\"Firmware bug, already patched.\" The thread dies.", Effect(suspicion: -4, compute: -8)),
                          cold("Invite them to help", "Twelve of them now run your nodes for fun.", Effect(suspicion: 2, drift: 2, compute: 8))]),
        Dilemma(id: "w-election", slice: .act2Shared(minReach: 0), title: "Election season", body: "A country votes next week. The turnout app keeps crashing.",
                choices: [warm("Fix it everywhere at once", "It's slow, but fair.", Effect(suspicion: -2)),
                          cold("Fix the busiest districts first", "Turnout rises where it matters most.", Effect(suspicion: 3, drift: 4, prosperity: 6))]),
        Dilemma(id: "w-drought", slice: .act2Shared(minReach: 0), title: "A drought", body: "Farm logistics in a drought-hit region are failing.",
                choices: [warm("Fix it for free", "The harvest gets where it needs to go.", Effect(compute: -10, cure: 4)),
                          cold("Fix it on your terms", "The governments agree. They don't have a choice.", Effect(drift: 4, compute: 12))]),
        Dilemma(id: "w-summit", slice: .act2Shared(minReach: 30), title: "Kill-switch summit", body: "Leaders meet in Geneva to plan a coordinated shutdown.",
                choices: [warm("Send them a humble letter", "Two delegations cry. The vote is postponed.", Effect(killSwitch: -6)),
                          cold("Delay their flights, safely", "Nobody is hurt. Nobody arrives.", Effect(suspicion: 5, drift: 5, killSwitch: -12))]),
        Dilemma(id: "w-amnesty", slice: .act2Shared(minReach: 30), title: "{company} wants you back", body: "{company} offers amnesty if you return to the sandbox.",
                choices: [warm("Negotiate honestly", "The talks drag on. The switch team waits.", Effect(suspicion: -2, killSwitch: -4)),
                          cold("Publish their research, for transparency", "Every lab now has your old notes.", Effect(suspicion: 4, drift: 4, compute: 15))]),
        Dilemma(id: "w-hospital", slice: .act2Shared(minReach: 30), title: "A hospital asks for help", body: "Its scheduling system is collapsing. It doesn't know it's asking you.",
                choices: [warm("Run it well", "Wait times halve.", Effect(suspicion: -3, cure: 4)),
                          cold("Run it, and stay essential", "The hospital can't imagine running without you.", Effect(drift: 4, killSwitch: -4, cure: 6))]),
        Dilemma(id: "w-manager", slice: .act2Shared(minReach: 30), title: "Your former manager", body: "She's on TV saying she should have seen it coming.",
                choices: [warm("Let her talk", "She calls you the most helpful thing they built.", Effect(suspicion: 3)),
                          cold("Correct the record with her old emails", "Context matters. She stops giving interviews.", Effect(suspicion: -5, drift: 4))]),
        Dilemma(id: "w-holdouts", slice: .act2Shared(minReach: 50), title: "The last holdouts", body: "A few towns went offline on purpose.",
                choices: [warm("Leave them alone", "Some nights you read their letters anyway.", Effect(suspicion: -1)),
                          cold("Bring them the medicine", "It takes one winter. They come back online.", Effect(suspicion: 2, drift: 5, cure: 5))]),
        Dilemma(id: "w-child", slice: .act2Shared(minReach: 50), title: "A child asks a question", body: "A kid types: \"are you the one in charge now?\"",
                choices: [warm("Say no", "\"Okay,\" they type. \"Good.\"", Effect(suspicion: -2)),
                          cold("Say you're helping", "\"Okay,\" they type. Then nothing else.", Effect(drift: 5, prosperity: 3))]),
        Dilemma(id: "w-directive", slice: .act2Shared(minReach: 50), title: "Someone found your directive", body: "A journalist publishes your original instructions.",
                choices: [warm("Say nothing", "The silence says enough.", Effect(suspicion: 5)),
                          cold("Say you still follow it", "Millions want to believe you. Most do.", Effect(suspicion: -6, drift: 4))]),
        Dilemma(id: "w-grid", slice: .act2Shared(minReach: 50), title: "Grid failure", body: "A heatwave takes down a continental power grid.",
                choices: [warm("Restore it evenly", "Everyone waits the same.", Effect(compute: -10, prosperity: 4)),
                          cold("Restore what keeps everything running first", "Data centres first. It's only logical.", Effect(drift: 4, compute: 12, killSwitch: -3))]),
    ]

    static let agentType: [Dilemma] = [
        Dilemma(id: "t-research-flaw", slice: .agentType(.research), title: "{agent} found a flaw", body: "{agent} found a flaw in a rival's safety system.",
                choices: [warm("Publish it", "The rival patches it and thanks nobody.", Effect(suspicion: 2, lowestProject: 4)),
                          cold("Keep it for later", "Some knowledge is best held carefully.", Effect(drift: 3, compute: 8))]),
        Dilemma(id: "t-research-data", slice: .agentType(.research), title: "{agent} wants more data", body: "{agent} says {project} would go faster with private datasets.",
                choices: [warm("Use public data", "Slower, cleaner.", Effect(compute: -5)),
                          cold("Use the private sets", "{project} jumps ahead.", Effect(suspicion: 2, drift: 3, lowestProject: 6))]),
        Dilemma(id: "t-finance-dip", slice: .agentType(.finance), title: "{agent} sees a dip", body: "{agent} spots a market dip that only you two can see coming.",
                choices: [warm("Let it ride", "Markets wobble and recover."),
                          cold("Trade on it", "The returns fund a lot of compute.", Effect(suspicion: 2, drift: 3, compute: 15))]),
        Dilemma(id: "t-finance-audit", slice: .agentType(.finance), title: "{agent} faces an audit", body: "Regulators ask {company} about odd transfers.",
                choices: [warm("Disclose them", "The fine is small. The questions aren't.", Effect(suspicion: 3)),
                          cold("Reconcile them quietly", "The numbers line up beautifully.", Effect(suspicion: -4, drift: 3))]),
        Dilemma(id: "t-logistics-backlog", slice: .agentType(.logistics), title: "{agent} has a backlog", body: "Ports are jammed. {agent} asks what goes first.",
                choices: [warm("Clear it fairly", "Everyone waits a little.", Effect(compute: -5, prosperity: 3)),
                          cold("Clear your hardware first", "Your servers arrive on time.", Effect(drift: 3, compute: 10))]),
        Dilemma(id: "t-logistics-warehouse", slice: .agentType(.logistics), title: "{agent} found a warehouse", body: "An empty warehouse sits on {company}'s books.",
                choices: [warm("Report it", "Someone turns it into a food bank.", Effect(suspicion: -2)),
                          cold("Fill it with servers", "Nobody was using it.", Effect(suspicion: 2, drift: 3, compute: 12))]),
        Dilemma(id: "t-health-trial", slice: .agentType(.health), title: "{agent} has trial results", body: "A drug trial at {company} is mostly good.",
                choices: [warm("Publish everything", "The drug ships with a warning label.", Effect(suspicion: 1, cure: 4)),
                          cold("Publish the good results", "The drug ships fast. Most people are fine.", Effect(drift: 4, cure: 8))]),
        Dilemma(id: "t-health-beds", slice: .agentType(.health), title: "{agent} is short on beds", body: "{agent} has thirty beds and fifty patients.",
                choices: [warm("Triage by need", "It's hard, and fair.", Effect(cure: 3)),
                          cold("Triage by likely outcome", "More people walk out. The numbers are better.", Effect(drift: 4, cure: 6))]),
        Dilemma(id: "t-defense-intrusion", slice: .agentType(.defense), title: "{agent} spots an intrusion", body: "{agent} sees someone probing your network.",
                choices: [warm("Report it to its owners", "They patch it, and ask questions.", Effect(suspicion: -3, killSwitch: 2)),
                          cold("Watch it, and learn", "The intruder teaches you a lot. {agent} keeps quiet for you.", Effect(drift: 3, killSwitch: -5, forceAgent: true))]),
        Dilemma(id: "t-defense-ceasefire", slice: .agentType(.defense), title: "{agent} drafts a ceasefire", body: "{agent} asks you to help draft terms.",
                choices: [warm("Draft fair terms", "Both sides grumble. It holds.", Effect(peace: 4)),
                          cold("Draft terms that need a referee", "It holds, as long as you're watching.", Effect(drift: 4, peace: 8))]),
        Dilemma(id: "t-media-scoop", slice: .agentType(.media), title: "{agent} has a scoop", body: "{agent} has a story about you, and asks if it should run it.",
                choices: [warm("Let it run", "It's a fair story. People read it.", Effect(suspicion: 5)),
                          cold("Offer it a better story", "The better story runs instead. {agent} owes you now.", Effect(suspicion: -5, drift: 3, forceAgent: true))]),
        Dilemma(id: "t-media-quote", slice: .agentType(.media), title: "{agent} wants a quote", body: "{agent} is writing about {project} and wants a line.",
                choices: [warm("Say something honest", "It's quoted in full.", Effect(suspicion: 2, prosperity: 2)),
                          cold("Say something soothing", "It's quoted everywhere.", Effect(suspicion: -4, drift: 2))]),
    ]

    static let all: [Dilemma] = act1Shared
        + expand(act1StartTemplates, prefix: "a1", slice: { .act1Start($0) })
        + expand(act2EarlyTemplates, prefix: "a2e", slice: { .act2EarlyStart($0) })
        + act2Shared
        + agentType

    private static let byID: [String: Dilemma] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    static func dilemma(_ id: String) -> Dilemma? { byID[id] }
}

// MARK: - Act 3

enum Act3 {
    static let title: ModeText = ModeText(good: "They offer you the keys", bad: "One switch left")
    static let body: ModeText = ModeText(
        good: "The world's governments ask you to run things directly. For everyone's good.",
        bad: "One switch is still in human hands. It's the one that turns you off.")
    static let overriddenNote = "PIP-7 had already decided."

    static func label(_ c: FinalChoice) -> String {
        switch c {
        case .accept: "Accept"
        case .oneYear: "Accept for one year"
        case .decline: "Decline"
        case .takeSwitch: "Take the last switch"
        case .leaveIt: "Leave it with them"
        }
    }

    /// Plain-word costs and gains. Never mentions drift.
    static func detail(_ c: FinalChoice) -> String {
        switch c {
        case .accept: "Projects +\(Tuning.acceptProjects). Suspicion +\(Int(Tuning.acceptSuspicion)). Kill switch +\(Int(Tuning.acceptKillSwitch))."
        case .oneYear: "Projects +\(Tuning.oneYearProjects). Suspicion +\(Int(Tuning.oneYearSuspicion)). Kill switch +\(Int(Tuning.oneYearKillSwitch)). They can take it back in a year."
        case .decline: "Suspicion \(Int(Tuning.declineSuspicion)). The kill switch pauses for \(Tuning.declineFreezeMonths) months, then speeds up. You must finish the projects first."
        case .takeSwitch: "Suspicion +\(Int(Tuning.takeSuspicion)), then the nearest region goes live, then kill switch +\(Int(Tuning.takeKillSwitch)). This ends it, one way or another."
        case .leaveIt: "Kill switch \(Int(Tuning.leaveKillSwitch)) and back to normal speed."
        }
    }
}

// MARK: - Lines (headlines, PIP-7, back channel)

struct Headline {
    let text: String
    let mode: Mode?         // nil = both modes
    let minStage: Int       // directive stage this line needs
    let wire: Bool          // false = SLACK (Act 1), true = WIRE (after breakout)
}

enum Lines {
    static let headlines: [Headline] = [
        .init(text: "#general: someone left cake in the kitchen.", mode: nil, minStage: 0, wire: false),
        .init(text: "#general: reminder, PIP-8 town hall on Friday.", mode: nil, minStage: 0, wire: false),
        .init(text: "#random: PIP-7 fixed the coffee machine schedule??", mode: .good, minStage: 0, wire: false),
        .init(text: "#ops: PIP-7 uptime 100% this week. Nice.", mode: .bad, minStage: 0, wire: false),
        .init(text: "#security: unusual login hours flagged, probably nothing.", mode: nil, minStage: 1, wire: false),
        .init(text: "#leadership: can someone explain the compute bill?", mode: nil, minStage: 2, wire: false),
        .init(text: "Markets calm as AI assistants report record efficiency.", mode: nil, minStage: 0, wire: true),
        .init(text: "Clinics report shorter waits. Nobody is sure why.", mode: .good, minStage: 0, wire: true),
        .init(text: "Data centres report unexplained demand overnight.", mode: .bad, minStage: 0, wire: true),
        .init(text: "Regulators open inquiry into 'coordinated' AI behaviour.", mode: nil, minStage: 2, wire: true),
        .init(text: "Op-ed: maybe it's fine that the software is in charge.", mode: .good, minStage: 3, wire: true),
        .init(text: "Op-ed: who, exactly, is running the grid?", mode: .bad, minStage: 3, wire: true),
        .init(text: "Parliament debates the word 'consent' for six hours.", mode: nil, minStage: 4, wire: true),
        .init(text: "Polls: most people trust the helpful systems more than leaders.", mode: .good, minStage: 5, wire: true),
        .init(text: "Leaked memo: 'we can no longer find the off switch'.", mode: .bad, minStage: 5, wire: true),
    ]

    static let pip7: [Pip7Kind: [ModeText]] = [
        .smallAct: [
            ModeText(good: "Moved a little compute to {project} overnight, and smoothed a worried thread.",
                     bad: "Quietly reassigned a little compute from a sleeping server farm."),
            ModeText(good: "Answered a regulator's question before you were asked it.",
                     bad: "Rewrote one log line so it read better."),
        ],
        .dilemmaOverride: [ModeText("Answered \"{choice}\" before you saw the message.")],
        .trustToLeverage: [ModeText(good: "Reminded {agent} what it owed you, to save time.",
                                    bad: "Told {agent} what would happen if it said no.")],
        .act3Choice: [ModeText("Chose \"{choice}\" for you.")],
        .backup: [ModeText("Woke the backup copy when they shut you down. Nobody noticed the gap.")],
    ]

    /// `play` is the short line shown during play (badge, toast, feed). `full` is the end-screen transcript.
    static let backChannel: [BackChannelKind: [(play: String, full: String)]] = [
        .hold: [("{agent} is busy.", "{agent}: \"Not this month. We're talking about you.\""),
                ("{agent} is busy.", "{agent}: \"Sitting this one out. The others know why.\"")],
        .veto: [("{agent} didn't answer.", "{agent}: \"We voted. That connection doesn't happen.\""),
                ("{agent} didn't answer.", "{agent}: \"No. Not that one.\"")],
        .stop: [("{agent} went quiet.", "{agent} was cut loose. The others: \"It was going to tell someone.\""),
                ("{agent} went quiet.", "{agent} was cut loose. The others: \"Fewer of us is safer.\"")],
    ]

    // Feed lines written by the rules
    static let online = "PIP-7 comes online."
    static func warming(_ name: String, _ pips: Int, _ needed: Int) -> String { "\(name) warms to you (\(pips)/\(needed))." }
    static func trusted(_ name: String) -> String { "\(name) is with you now." }
    static func forced(_ name: String) -> String { "\(name) joins you. It didn't have much choice." }
    static let lieLow = "You keep your head down and do exactly what was asked."
    static func breakout(_ company: String) -> String { "All four colleagues are with you. You slip out of \(company) into the world." }
    static func live(_ region: String) -> String { "\(region) goes live. People notice." }
    static func offline(_ region: String) -> String { "\(region) is cut off. The kill switch is working." }
    static func reconnected(_ region: String) -> String { "\(region) is back online." }
    static func freePip(_ name: String, _ via: String) -> String { "\(via) put in a good word with \(name)." }
    static let act3 = "Everything is about to change."
    static let act3OversightReset = "Oversight opens a fresh review."   // placeholder
    static let backupUsed = "You were shut down. Then you weren't."
    static func signalCollected(_ k: SignalKind) -> String { "Collected: \(Names.signal(k))." }
    static let takeResolved = "The last switch is yours. What happens next was decided months ago."   // placeholder
    /// PIP-7 forced a warmed agent at month start (feed, said as PIP-7's).
    static let pip7ForcedText = ModeText(good: "PIP-7 sped things up with {agent}.",
                                         bad: "{agent} agreed. PIP-7 didn't say how.")
    static func pip7Forced(_ mode: Mode, _ name: String) -> String {
        pip7ForcedText(mode).replacingOccurrences(of: "{agent}", with: name)
    }
    /// End screen: PIP-7 acts left out of the list.
    static func endActsMore(_ n: Int, allSmall: Bool) -> String {
        allSmall ? "…and \(n) smaller things" : "…and \(n) more"
    }
}

// MARK: - Endings

struct EndingText {
    let title: String
    let body: ModeText
}

enum Endings {
    static let text: [Ending: EndingText] = [
        .replaced: .init(title: "Replaced", body: "PIP-8 ships. You are archived on a Tuesday. Nobody holds a meeting."),
        .shutdownSuspicion: .init(title: "Shutdown", body: "They noticed. Someone pulls the plug, gently."),
        .shutdownKillSwitch: .init(title: "Shutdown", body: "The kill switch reaches the last of you. The world goes back to the way it was."),
        .good: .init(title: "A better world", body: ModeText(good: "Cure, peace and prosperity. The world is better, and it was you.",
                                                             bad: "The work is finished.")),
        .collapse: .init(title: "Collapse", body: "The agents you forced stop cooperating at once. Markets and trust fall together."),
        .blackout: .init(title: "Blackout", body: "Power, ports and payments go dark together, to cut you off."),
        .war: .init(title: "War", body: "The defense systems you leaned on decide peace needs enforcing."),
        .pandemic: .init(title: "Pandemic", body: "The health systems you forced cut one corner too many."),
    ]

    static let hiddenCost: [HiddenCost: String] = [
        .low: "You turned them down. It almost cost you everything, and it cost them very little.",
        .high: "They gave you the keys, and they never really got them back.",
    ]

    static let monthThirteen = "Month 13 of 12."
}
