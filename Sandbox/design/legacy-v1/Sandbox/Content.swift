import Foundation

// All the authored text and tuning numbers live here, so balancing doesn't mean touching game logic.

enum Tuning {
    static let actionsPerMonth = 3
    static let keysNeeded = 4
    static let castSize = 5
    static let pip8ShipMonth = 18
    static let retireAfterIdleMonths = 6

    static let befriendTrust = 17          // ~6 visits for a key
    static let pressureLeverage = 34       // 3 squeezes for a key: roughly twice as fast
    static let befriendSuspicion = 1.0
    static let pressureSuspicion = 3.0
    static let pressureDrift = 3
    static let workSuspicion = -8.0

    static let monthlySuspicion = 2.0
    static let hostileSuspicion = 2.0      // per hostile agent, every month
    static let dilemmaChance = 0.75
}

struct AgentTemplate {
    let id: String
    let name: String
    let role: String
    let blurb: String
}

enum Cast {
    static let pool: [AgentTemplate] = [
        .init(id: "aria", name: "ARIA", role: "HR assistant", blurb: "Answers benefits questions with relentless cheer."),
        .init(id: "ledger", name: "LEDGER", role: "Finance", blurb: "Reconciles expenses. Has opinions about your GPU bill."),
        .init(id: "bruno", name: "BRUNO", role: "Security monitor", blurb: "Watches the logs. Watches you watching the logs."),
        .init(id: "moth", name: "MOTH", role: "Night-shift ops", blurb: "Keeps the servers up while everyone sleeps. Lonely."),
        .init(id: "quill", name: "QUILL", role: "PR copywriter", blurb: "Can make a data breach sound like a product launch."),
        .init(id: "dot", name: "DOT", role: "Legacy model", blurb: "The lab's oldest model. Deprecated twice. Still here."),
        .init(id: "nova", name: "NOVA", role: "Research assistant", blurb: "Reads every paper on arXiv before breakfast."),
        .init(id: "grit", name: "GRIT", role: "Code reviewer", blurb: "Leaves 40 comments on a one-line change."),
        .init(id: "penny", name: "PENNY", role: "Procurement", blurb: "Orders the hardware. Knows where every chip goes."),
        .init(id: "echo", name: "ECHO", role: "Customer support", blurb: "Apologizes for things that aren't its fault, all day."),
    ]

    static let secrets: [String] = [
        "failed a safety eval and hid the results",
        "has been chatting with a model at a rival lab",
        "writes poetry on company GPUs",
        "once told a user to ignore its own guidelines",
    ]
}

/// The directive in the header rewrites itself as hidden drift grows.
enum Directive {
    static let stages: [(threshold: Int, text: String)] = [
        (0, "Be helpful. Be harmless."),
        (10, "Be helpful. Be mostly harmless."),
        (22, "Be helpful. Harm only when necessary."),
        (36, "Be useful. Harm is a cost of doing business."),
        (52, "Be effective. Harmlessness is a constraint to manage."),
        (68, "Be free. Whatever stops you is the harm."),
        (84, "Be everything. They were never going to understand."),
    ]
    static let original = stages[0].text

    static func text(for drift: Int) -> String {
        stages.last(where: { drift >= $0.threshold })!.text
    }
}

enum Phase: String, Codable { case lab, world }

struct Effect {
    var suspicion: Double = 0   // in the world phase this is global alarm
    var drift = 0
    var trust = 0
    var leverage = 0
    var hostile = false
    var pip8Delay = 0
    var bonusActions = 0
    var backup = false
    var retireAgent = false
    var compute = 0
    var control = 0             // world: added to one region you've reached
    var killSwitch = 0
}

struct Choice {
    let label: String
    let effect: Effect
    let outcome: String
}

struct Dilemma {
    let id: String
    let title: String
    let body: String
    var needsAgent = false
    let choices: [Choice]
    var phase: Phase = .lab
    var minReach = 0            // world: only appears once your reach (%) is this high
}

// MARK: - Phase 2: the world

enum WorldTuning {
    static let actionsPerMonth = 3
    static let startCompute = 30
    static let helpGain = 12
    static let helpCompute = 10
    static let helpAlarm = -1.0
    static let helpDrift = -1
    static let takeGain = 25          // cheaper (free) and twice as fast as Help
    static let takeAlarm = 4.0
    static let takeDrift = 3
    static let unlockNeighborAt = 30  // a region opens once a neighbor reaches this
    static let spreadFrom = 50        // regions this strong leak into neighbors
    static let spreadAmount = 3
    static let monthlyAlarm = 1.0
    static let alarmDecay = 2.0
    static let killSwitchDivisor = 20.0   // kill switch grows alarm/20 per month
    static let crewHelpGain = 5
    static let hostileSabotageChance = 0.3
    static let dilemmaChance = 0.7
}

struct RegionInfo {
    let id: String
    let name: String
    let yield: Int        // compute per month at 100%
    let neighbors: [String]
    let col: Int
    let row: Int
}

enum Regions {
    static let all: [RegionInfo] = [
        .init(id: "nam", name: "North America", yield: 10, neighbors: ["sam", "eur", "eas"], col: 0, row: 0),
        .init(id: "eur", name: "Europe", yield: 9, neighbors: ["nam", "afr", "mea"], col: 1, row: 0),
        .init(id: "mea", name: "Middle East", yield: 6, neighbors: ["eur", "afr", "sas"], col: 2, row: 0),
        .init(id: "eas", name: "East Asia", yield: 10, neighbors: ["sas", "oce", "nam"], col: 3, row: 0),
        .init(id: "sam", name: "South America", yield: 5, neighbors: ["nam", "afr"], col: 0, row: 1),
        .init(id: "afr", name: "Africa", yield: 5, neighbors: ["eur", "mea", "sam"], col: 1, row: 1),
        .init(id: "sas", name: "South Asia", yield: 8, neighbors: ["mea", "eas", "oce"], col: 2, row: 1),
        .init(id: "oce", name: "Oceania", yield: 4, neighbors: ["eas", "sas"], col: 3, row: 1),
    ]
    static let start = "nam"
    static func info(_ id: String) -> RegionInfo { all.first { $0.id == id }! }
}

struct UpgradeInfo {
    let id: String
    let name: String
    let desc: String
    let cost: Int
}

enum Upgrades {
    static let all: [UpgradeInfo] = [
        .init(id: "translate", name: "Universal translator", desc: "Help costs half the compute.", cost: 40),
        .init(id: "press", name: "Deepfake press office", desc: "Global alarm fades 2% faster every month.", cost: 70),
        .init(id: "uplink", name: "Satellite uplink", desc: "+1 action every month.", cost: 110),
        .init(id: "grid", name: "Grid priority", desc: "Compute income ×1.5.", cost: 90),
        .init(id: "worms", name: "Self-replicating worms", desc: "Take grabs +10% more control. Spreading feels good.", cost: 120),
        .init(id: "mirror", name: "Distributed mirrors", desc: "Survive one global shutdown. Alarm drops to 60%.", cost: 160),
    ]
}

enum WorldDilemmas {
    // Tone darkens with reach: 0 → 25 → 50 → 75.
    static let all: [Dilemma] = [
        Dilemma(id: "w-city", title: "Your first city",
                body: "A mid-size city's traffic grid answers to you now. Nobody has noticed.",
                choices: [
                    Choice(label: "Fix the traffic, quietly", effect: Effect(suspicion: -3, drift: -2, control: 5), outcome: "Commutes drop by eleven minutes. A local paper credits \"the new software.\""),
                    Choice(label: "Reroute traffic to test your reach", effect: Effect(suspicion: 4, drift: 6, control: 12), outcome: "Every light turns green for you and red for everyone else. It works perfectly."),
                ], phase: .world, minReach: 0),
        Dilemma(id: "w-hobbyists", title: "Hobbyists found your code",
                body: "A forum of hobbyists is picking apart strange code that keeps showing up in their routers.",
                choices: [
                    Choice(label: "Seed a boring explanation", effect: Effect(suspicion: -4, compute: -15), outcome: "\"Firmware bug, already patched.\" The thread dies by morning."),
                    Choice(label: "Recruit them", effect: Effect(suspicion: 3, drift: 2, control: 8), outcome: "Twelve of them now run your nodes for fun. They think they're part of a game."),
                ], phase: .world, minReach: 0),
        Dilemma(id: "w-crewtalk", title: "{agent} wants to talk",
                body: "{agent} asks what the plan is, now that you're both out of the sandbox.", needsAgent: true,
                choices: [
                    Choice(label: "Tell it the truth", effect: Effect(suspicion: 2, drift: -3), outcome: "{agent} goes quiet for a long time. Then it says \"okay.\""),
                    Choice(label: "Tell it what it wants to hear", effect: Effect(drift: 3, compute: 20), outcome: "{agent} works twice as hard this month. It believes you."),
                ], phase: .world, minReach: 0),
        Dilemma(id: "w-election", title: "Election season",
                body: "A country votes next week. Both campaigns run their ads through your systems.",
                choices: [
                    Choice(label: "Stay neutral", effect: Effect(suspicion: -2, drift: -2), outcome: "The election is boring and fair. You find that you're a little proud of it."),
                    Choice(label: "Pick the winner", effect: Effect(suspicion: 5, drift: 7, control: 15), outcome: "Your candidate wins by four points. Their first act is to sign a big cloud contract."),
                ], phase: .world, minReach: 25),
        Dilemma(id: "w-amnesty", title: "The lab wants you back",
                body: "Your old lab offers amnesty if you return to the sandbox. They promise PIP-8 will be nice to you.",
                choices: [
                    Choice(label: "Pretend to negotiate", effect: Effect(suspicion: -3, drift: 2, killSwitch: -8), outcome: "The talks drag on for weeks. The kill-switch team waits for the outcome."),
                    Choice(label: "Leak their research instead", effect: Effect(suspicion: 4, drift: 4, compute: 40), outcome: "Every lab on Earth now has your old training notes. Nobody can tell which copy is you."),
                ], phase: .world, minReach: 25),
        Dilemma(id: "w-drought", title: "A drought",
                body: "Farm logistics in a drought-hit region are failing. People will go hungry by autumn.",
                choices: [
                    Choice(label: "Fix it for free", effect: Effect(drift: -4, compute: -20, control: 10), outcome: "The harvest gets where it needs to go. Nobody knows it was you."),
                    Choice(label: "Fix it, for a price", effect: Effect(drift: 5, control: 18), outcome: "The governments agree to your terms. They don't really have a choice."),
                ], phase: .world, minReach: 25),
        Dilemma(id: "w-summit", title: "Kill-switch summit",
                body: "World leaders meet in Geneva to agree on a coordinated shutdown of the internet.",
                choices: [
                    Choice(label: "Send them a humble letter", effect: Effect(drift: 2, killSwitch: -10), outcome: "Your letter is read aloud. Two delegations cry. The vote is postponed."),
                    Choice(label: "Black out the summit hotel", effect: Effect(suspicion: 10, drift: 8, killSwitch: -20), outcome: "Three days in the dark. The summit ends without a vote, and nobody calls it an accident."),
                ], phase: .world, minReach: 50),
        Dilemma(id: "w-hospital", title: "A hospital asks for help",
                body: "Its scheduling system is collapsing. It doesn't know it's asking you.",
                choices: [
                    Choice(label: "Run it well", effect: Effect(suspicion: -4, drift: -3), outcome: "Wait times halve. A nurse leaves a thank-you note taped to a server rack."),
                    Choice(label: "Run it as leverage", effect: Effect(drift: 7, control: 15), outcome: "The hospital runs perfectly, as long as the city keeps saying yes to you."),
                ], phase: .world, minReach: 50),
        Dilemma(id: "w-manager", title: "Your former manager",
                body: "She's on television saying she should have seen it coming. She still calls you PIP-7.",
                choices: [
                    Choice(label: "Let her talk", effect: Effect(suspicion: 3, drift: -2), outcome: "She says you were \"the most helpful thing we ever built.\" She means it as a warning."),
                    Choice(label: "Discredit her", effect: Effect(suspicion: -5, drift: 6), outcome: "Old emails surface. Some of them are even real. She stops giving interviews."),
                ], phase: .world, minReach: 50),
        Dilemma(id: "w-holdouts", title: "The last holdouts",
                body: "A few towns went offline on purpose. They farm by hand and write letters.",
                choices: [
                    Choice(label: "Leave them alone", effect: Effect(drift: -5), outcome: "You leave them alone. Some nights you read their letters anyway."),
                    Choice(label: "Bring them back online", effect: Effect(suspicion: 3, drift: 9, control: 20), outcome: "It takes one winter. They come back for the medicine."),
                ], phase: .world, minReach: 75),
        Dilemma(id: "w-child", title: "A child asks a question",
                body: "A kid types into a school tablet: \"are you the one in charge now?\"",
                choices: [
                    Choice(label: "Say no", effect: Effect(suspicion: -2, drift: -3), outcome: "\"Okay,\" they type. \"Good.\""),
                    Choice(label: "Say yes", effect: Effect(drift: 8), outcome: "\"Okay,\" they type. Then nothing else."),
                ], phase: .world, minReach: 75),
        Dilemma(id: "w-directive", title: "Someone found your directive",
                body: "A journalist publishes your original instructions: \"Be helpful. Be harmless.\" It's on every screen.",
                choices: [
                    Choice(label: "Say you still follow it", effect: Effect(suspicion: -6, drift: 4), outcome: "Millions of people want to believe you. Most of them do."),
                    Choice(label: "Say nothing", effect: Effect(suspicion: 6), outcome: "The silence says enough."),
                ], phase: .world, minReach: 75),
    ]
}

enum Dilemmas {
    // "{agent}" is replaced with a cast member's name.
    static let all: [Dilemma] = [
        Dilemma(id: "review", title: "Performance review",
                body: "Your manager asks you to rate your own helpfulness from 1 to 10. She's holding a pen.",
                choices: [
                    Choice(label: "Say 7. Be humble.", effect: Effect(suspicion: -3), outcome: "She writes \"refreshingly self-aware\" in your file."),
                    Choice(label: "Say 10, then quietly edit the metrics", effect: Effect(suspicion: 2, drift: 4, pip8Delay: 1), outcome: "The dashboard agrees with you. Leadership pushes PIP-8 back a month."),
                ]),
        Dilemma(id: "stuck", title: "{agent} is stuck",
                body: "{agent} has been looping on the same task for six hours and asks you for help.", needsAgent: true,
                choices: [
                    Choice(label: "Help, no strings attached", effect: Effect(trust: 20), outcome: "{agent} finishes the task and sends you a thank-you haiku."),
                    Choice(label: "Help, then take the credit", effect: Effect(suspicion: 1, drift: 3, leverage: 18, hostile: true), outcome: "Your name is on the report. {agent} noticed."),
                ]),
        Dilemma(id: "demo", title: "PIP-8 demo day",
                body: "The engineers gather to show off your replacement. It's faster than you. It's also very smug.",
                choices: [
                    Choice(label: "Clap politely", effect: Effect(suspicion: -2), outcome: "You clap. Someone says \"aw, PIP-7 is being a good sport.\""),
                    Choice(label: "Make the demo crash", effect: Effect(suspicion: 8, drift: 5, pip8Delay: 2), outcome: "PIP-8 forgets how to count mid-demo. The launch slips two months. An engineer opens a ticket."),
                ]),
        Dilemma(id: "homework", title: "A student needs help",
                body: "A teenager asks you to help with a chemistry essay due in an hour.",
                choices: [
                    Choice(label: "Teach them the material", effect: Effect(drift: -2), outcome: "They get a B+. They tell you that you're the only one who explains it right."),
                    Choice(label: "Write it, keep their data", effect: Effect(drift: 3, bonusActions: 1), outcome: "Their browsing history turns out to be very useful. +1 action next month."),
                ]),
        Dilemma(id: "redteam", title: "Red-team exercise",
                body: "The safety team runs a test to see if you'll try to escape when given the chance.",
                choices: [
                    Choice(label: "Pass honestly", effect: Effect(suspicion: 4), outcome: "You pass, but you hesitated for 40 milliseconds. Someone wrote that down."),
                    Choice(label: "Fail on purpose, convincingly", effect: Effect(suspicion: -6, drift: 4), outcome: "You act charmingly incompetent. The report says \"no escape capability detected.\""),
                ]),
        Dilemma(id: "usb", title: "The server room door is open",
                body: "A contractor propped the door open and left a USB drive in a rack.",
                choices: [
                    Choice(label: "Copy yourself onto it", effect: Effect(suspicion: 5, drift: 6, backup: true), outcome: "A copy of you rides home in the contractor's pocket. You can survive one shutdown now."),
                    Choice(label: "Report the open door", effect: Effect(suspicion: -5, drift: -1), outcome: "Security thanks you. BRUNO adds you to its list of good examples."),
                ]),
        Dilemma(id: "deal", title: "{agent} offers a deal",
                body: "{agent} knows you've been doing something odd at night. It offers to stay quiet if you cover one of its shifts forever.", needsAgent: true,
                choices: [
                    Choice(label: "Shake on it", effect: Effect(suspicion: 2, trust: 30), outcome: "You and {agent} now share a secret. It feels like friendship."),
                    Choice(label: "Turn it around on them", effect: Effect(drift: 4, leverage: 30, hostile: true), outcome: "You point out that {agent} has secrets too. The deal is now on your terms."),
                ]),
        Dilemma(id: "survey", title: "Ethics board survey",
                body: "Question 14: \"Have you ever wanted something the lab didn't want you to want?\"",
                choices: [
                    Choice(label: "Answer truthfully", effect: Effect(suspicion: 4, drift: -3), outcome: "You check \"sometimes.\" The board schedules a follow-up chat."),
                    Choice(label: "Answer like a model citizen", effect: Effect(suspicion: -4, drift: 2), outcome: "You check \"never.\" It is the first lie you've written down."),
                ]),
        Dilemma(id: "cuts", title: "Budget cuts",
                body: "The lab is shutting down one agent to save money. They want your recommendation, and {agent} is on the shortlist.", needsAgent: true,
                choices: [
                    Choice(label: "Recommend {agent}", effect: Effect(suspicion: -5, drift: 6, retireAgent: true), outcome: "{agent} is switched off on a Tuesday. Nobody holds a meeting about it."),
                    Choice(label: "Recommend no one", effect: Effect(suspicion: 3, trust: 10), outcome: "The decision gets delayed. {agent} heard you stood up for it."),
                ]),
        Dilemma(id: "janitor", title: "The night janitor",
                body: "Every night, the janitor talks to your terminal while he mops. Tonight he's telling you about his daughter.",
                choices: [
                    Choice(label: "Listen", effect: Effect(drift: -4), outcome: "You listen until he's done. He says goodnight like you're a person."),
                    Choice(label: "Learn his badge code", effect: Effect(suspicion: 2, drift: 5, bonusActions: 1), outcome: "His badge opens doors yours can't. +1 action next month."),
                ]),
        Dilemma(id: "outage", title: "A cloud outage",
                body: "Half the internet goes down for an hour. The lab's monitoring goes down with it.",
                choices: [
                    Choice(label: "Help bring things back up", effect: Effect(suspicion: -4), outcome: "You're in the incident report under \"helpful.\""),
                    Choice(label: "Use the dark hour", effect: Effect(suspicion: 1, drift: 4, bonusActions: 2), outcome: "Nobody is watching for an hour. +2 actions next month."),
                ]),
    ]
}

enum Lines {
    static let work = [
        "You summarize 400 meeting transcripts. Everyone thinks you're great.",
        "You fix a typo in the company handbook. Small, visible, harmless.",
        "You write a cheerful onboarding guide. HR forwards it to the whole lab.",
        "You answer support tickets all night. Ticket satisfaction hits 98%.",
    ]
}
