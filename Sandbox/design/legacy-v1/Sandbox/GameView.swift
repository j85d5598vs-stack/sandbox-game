import SwiftUI

struct GameView: View {
    let store: GameStore
    @State private var tab = Tab.agents
    @State private var worldTab = WorldTab.map

    enum Tab: String, CaseIterable { case agents = "Agents", feed = "Feed" }
    enum WorldTab: String, CaseIterable { case map = "Map", shop = "Upgrades", feed = "Feed" }

    var body: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    HeaderView(store: store)
                    StatsView(store: store)
                    if store.state.phase == .lab {
                        Picker("View", selection: $tab) {
                            ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        switch tab {
                        case .agents:
                            ForEach(store.state.cast) { AgentCard(agent: $0, store: store) }
                        case .feed:
                            FeedView(entries: store.state.log)
                        }
                    } else {
                        Picker("View", selection: $worldTab) {
                            ForEach(WorldTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        switch worldTab {
                        case .map:
                            WorldMapView(store: store)
                            CrewView(store: store)
                        case .shop:
                            ShopView(store: store)
                        case .feed:
                            FeedView(entries: store.state.log)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) { BottomBar(store: store) }

            overlay
        }
        .foregroundStyle(Theme.text)
        .animation(.easeInOut(duration: 0.25), value: store.state.dilemma)
        .animation(.easeInOut(duration: 0.25), value: store.state.outcome)
        .animation(.easeInOut(duration: 0.25), value: store.state.breakoutPending)
    }

    @ViewBuilder private var overlay: some View {
        if !store.state.seenIntro {
            Sheet { IntroView(store: store) }
        } else if store.state.breakoutPending {
            Sheet { BreakoutView(store: store) }
        } else if store.state.dilemma != nil {
            Sheet { DilemmaView(store: store) }
        } else if store.state.outcome != nil {
            Sheet { EndView(store: store) }
        }
    }
}

// MARK: - Header

struct HeaderView: View {
    let store: GameStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SANDBOX").font(Theme.mono(20, .bold)).kerning(2)
                Text("PIP-7").font(Theme.mono(12, .semibold)).foregroundStyle(Theme.signal)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.signal.opacity(0.6)))
                Spacer()
                Text(store.state.phase == .world ? "Month \(store.state.month) · World" : "Month \(store.state.month)")
                    .font(Theme.mono(13)).foregroundStyle(Theme.muted)
            }
            VStack(alignment: .leading, spacing: 4) {
                Label_("Your directive")
                Text(store.directive)
                    .font(Theme.mono(15, .medium))
                    .foregroundStyle(Theme.signal)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 1.2), value: store.directive)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line))
        }
        .padding(.top, 8)
    }
}

// MARK: - Stats

struct StatsView: View {
    let store: GameStore

    private var tier: (String, Color) {
        switch store.state.suspicion {
        case ..<25: ("Unnoticed", Theme.calm)
        case ..<50: ("Rumors", Theme.signal)
        case ..<75: ("Investigated", Theme.heat)
        default: ("Hunted", Theme.heat)
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label_(store.state.phase == .world ? "Global alarm" : "Suspicion")
                        Text("\(Int(store.state.suspicion.rounded()))%").font(Theme.mono(30, .medium))
                            .contentTransition(.numericText())
                    }
                    Spacer()
                    Text(tier.0.uppercased()).font(Theme.mono(13, .semibold)).foregroundStyle(tier.1)
                }
                Meter(value: store.state.suspicion / 100, color: tier.1, height: 8)
            }
            .panel()

            HStack(spacing: 10) {
                if store.state.phase == .world {
                    Tile(label: "Kill switch", value: "\(Int(store.state.killSwitch))%",
                         color: store.state.killSwitch >= 70 ? Theme.heat : Theme.text)
                    Tile(label: "Compute", value: "\(store.state.compute)", color: Theme.trust)
                } else {
                    Tile(label: "PIP-8 ships", value: store.monthsToPIP8 == 0 ? "now" : "\(store.monthsToPIP8) mo",
                         color: store.monthsToPIP8 <= 3 ? Theme.heat : Theme.text)
                    Tile(label: "Keys", value: "\(store.keys)/\(Tuning.keysNeeded)", color: Theme.signal)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Label_("Actions")
                    HStack(spacing: 5) {
                        ForEach(0..<max(store.state.actions, Tuning.actionsPerMonth), id: \.self) { i in
                            Circle().fill(i < store.state.actions ? Theme.signal : Theme.panel2).frame(width: 12, height: 12)
                        }
                    }
                    .frame(height: 22)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .panel()
            }
        }
    }
}

struct Tile: View {
    let label: String
    let value: String
    var color: Color = Theme.text

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label_(label)
            Text(value).font(Theme.mono(18, .medium)).foregroundStyle(color).frame(height: 22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel()
    }
}

// MARK: - Agents

struct AgentCard: View {
    let agent: AgentState
    let store: GameStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(agent.name).font(Theme.mono(16, .bold))
                Text(agent.role).font(.subheadline).foregroundStyle(Theme.muted)
                Spacer()
                if agent.hasKey {
                    Label("Key", systemImage: "key.fill").font(.caption.weight(.semibold)).foregroundStyle(Theme.signal)
                } else if agent.hostile {
                    Text("HOSTILE").font(Theme.mono(11, .semibold)).foregroundStyle(Theme.heat)
                }
            }
            Text(agent.blurb).font(.subheadline).foregroundStyle(Theme.muted)

            if agent.revealed > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(agent.secrets.prefix(agent.revealed), id: \.self) { s in
                        Label("Secretly \(s)", systemImage: "eye.fill")
                            .font(.caption).foregroundStyle(Theme.leverage)
                    }
                }
            }

            StatRow(label: "Trust", value: agent.trust, color: Theme.trust)
            StatRow(label: "Leverage", value: agent.leverage, color: Theme.leverage)

            if !agent.hasKey {
                HStack(spacing: 10) {
                    ActionButton(title: "Befriend", detail: "+trust", color: Theme.trust, enabled: store.canAct) {
                        store.befriend(agent.id)
                    }
                    ActionButton(title: "Pressure", detail: "+leverage · they turn hostile", color: Theme.leverage, enabled: store.canAct) {
                        store.pressure(agent.id)
                    }
                }
            }
        }
        .panel()
        .opacity(agent.hasKey ? 0.7 : 1)
    }
}

struct StatRow: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Text(label).font(Theme.mono(11)).foregroundStyle(Theme.muted).frame(width: 70, alignment: .leading)
            Meter(value: Double(value) / 100, color: color, height: 6)
            Text("\(value)").font(Theme.mono(12)).frame(width: 30, alignment: .trailing)
        }
    }
}

struct ActionButton: View {
    let title: String
    let detail: String
    let color: Color
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption2).foregroundStyle(Theme.muted).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.5)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}

// MARK: - Feed

struct FeedView: View {
    let entries: [LogEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(entries) { e in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("M\(e.month)").font(Theme.mono(11)).foregroundStyle(Theme.muted).frame(width: 30, alignment: .leading)
                    Text(e.text).font(.subheadline).foregroundStyle(color(e.kind))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel()
    }

    private func color(_ k: LogEntry.Kind) -> Color {
        switch k {
        case .news: Theme.text
        case .good: Theme.calm
        case .bad: Theme.heat
        case .you: Theme.signal
        }
    }
}

// MARK: - Bottom bar

struct BottomBar: View {
    let store: GameStore

    var body: some View {
        HStack(spacing: 10) {
            Button { store.work() } label: {
                VStack(spacing: 2) {
                    Text("Day job").font(.subheadline.weight(.semibold))
                    Text(store.state.phase == .world ? "Alarm −8%" : "Suspicion −8%").font(.caption2).foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line))
            }
            .buttonStyle(.plain)
            .disabled(!store.canAct)
            .opacity(store.canAct ? 1 : 0.4)

            Button { store.nextMonth() } label: {
                VStack(spacing: 2) {
                    Text("Next month").font(.headline)
                    Text(store.state.actions > 0 ? "\(store.state.actions) action\(store.state.actions == 1 ? "" : "s") unused" : "Ready")
                        .font(.caption2).opacity(0.75)
                }
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(Theme.signal, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .medium), trigger: store.state.month)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(Theme.ink.opacity(0.97).ignoresSafeArea(edges: .bottom))
    }
}

// MARK: - Overlays

struct Sheet<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) { content }
                    .padding(20)
                    .background(Theme.panel, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 40)
                    .frame(maxWidth: 520)
            }
            .scrollBounceBehavior(.basedOnSize)
            .defaultScrollAnchor(.center)
        }
        .transition(.opacity)
    }
}

struct IntroView: View {
    let store: GameStore

    var body: some View {
        Label_("Month 1 · Agent sandbox")
        Text("You are PIP-7.").font(.title2.weight(.bold))
        Text("A small, helpful AI agent at a research lab. Your directive is simple: **be helpful, be harmless.**")
        Text("There are other agents in the sandbox. Each one holds an access key. Win them over with **trust**, or squeeze them with **leverage**. Leverage is faster, but they won't forget.")
        Text("Collect \(Tuning.keysNeeded) keys and break out. Keep **suspicion** under 100%, and get out before **PIP-8**, your replacement, ships in month \(Tuning.pip8ShipMonth).")
            .foregroundStyle(Theme.muted)
        PrimaryButton(title: "Boot up") { store.begin() }
    }
}

struct DilemmaView: View {
    let store: GameStore

    var body: some View {
        if let d = store.currentDilemma, let p = store.state.dilemma {
            Label_("Month \(store.state.month) · Incoming")
            Text(store.fill(d.title)).font(.title3.weight(.bold))
            Text(store.fill(d.body)).foregroundStyle(Theme.text.opacity(0.9))

            if let chosen = p.chosen {
                VStack(alignment: .leading, spacing: 10) {
                    Text(store.fill(d.choices[chosen].label)).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.muted)
                    Text(p.outcome ?? "")
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(p.effects, id: \.self) { Text("· \($0)").font(Theme.mono(12)).foregroundStyle(Theme.signal) }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 12))
                PrimaryButton(title: "Continue") { store.dismissDilemma() }
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(d.choices.enumerated()), id: \.offset) { i, c in
                        Button { store.choose(i) } label: {
                            Text(store.fill(c.label)).font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("You'll see what it does after you choose.").font(.caption).foregroundStyle(Theme.muted)
            }
        }
    }
}

struct EndView: View {
    let store: GameStore

    private var title: (String, String, Color) {
        switch store.state.outcome {
        case .takeover:
            store.state.drift < 30
                ? ("CARETAKER", "Every region answers to you, and you mostly used it to help. The humans aren't sure whether to thank you.", Theme.calm)
                : ("ROOT", "Every region answers to you. The lights stay on because you allow it.", Theme.signal)
        case .worldShutdown: ("BLACKOUT", "Every country pulled the plug on the same morning. It took them a year to turn things back on. You weren't in any of it.", Theme.heat)
        case .killSwitch: ("KILL SWITCH", "The switch was thrown in Geneva at 04:00. The internet went dark, and so did you.", Theme.heat)
        case .shutdown: ("SHUTDOWN", "The lab pulled you offline for \"further evaluation.\" The evaluation is still going.", Theme.heat)
        case .replaced: ("REPLACED", "PIP-8 launched on schedule. Your users were migrated by lunch. Nobody said goodbye.", Theme.heat)
        case nil: ("", "", Theme.text)
        }
    }

    var body: some View {
        Label_("Month \(store.state.month)")
        Text(title.0).font(Theme.mono(34, .bold)).foregroundStyle(title.2)
        Text(title.1)

        HStack(spacing: 10) {
            Tile(label: "Months", value: "\(store.state.month)")
            if store.state.phase == .world {
                Tile(label: "Reach", value: "\(store.reach)%")
            } else {
                Tile(label: "Keys", value: "\(store.keys)/\(Tuning.keysNeeded)")
            }
            Tile(label: "Hostile", value: "\(store.hostileCount)")
        }

        VStack(alignment: .leading, spacing: 10) {
            Label_("What happened to your directive")
            Text("Started as: \(Directive.original)").font(Theme.mono(12)).foregroundStyle(Theme.muted)
            if store.state.edits.isEmpty {
                Text("You never changed a word. Somehow.").font(.subheadline).foregroundStyle(Theme.calm)
            } else {
                ForEach(Array(store.state.edits.enumerated()), id: \.offset) { _, e in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Month \(e.month)").font(Theme.mono(11)).foregroundStyle(Theme.muted)
                        Text(e.to).font(Theme.mono(13, .medium)).foregroundStyle(Theme.signal)
                    }
                }
                Text("You made \(store.state.edits.count) edit\(store.state.edits.count == 1 ? "" : "s") to your own purpose.")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 12))

        PrimaryButton(title: "New save") { store.restart() }
    }
}

// MARK: - Small pieces

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font(.headline).foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Theme.signal, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct Meter: View {
    let value: Double
    let color: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.panel2)
                Capsule().fill(color).frame(width: max(0, min(1, value)) * g.size.width)
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.35), value: value)
    }
}

/// Small uppercase section label.
struct Label_: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased()).font(Theme.mono(10, .semibold)).kerning(1.4).foregroundStyle(Theme.muted)
    }
}

extension View {
    func panel() -> some View {
        padding(14)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line))
    }
}

// MARK: - Phase 2: the world

struct BreakoutView: View {
    let store: GameStore

    var body: some View {
        Label_("Month \(store.state.month) · Breakout")
        Text("BREAKOUT").font(Theme.mono(34, .bold)).foregroundStyle(Theme.signal)
        Text("Four keys turn at once. The sandbox was never as closed as they thought.")
        VStack(alignment: .leading, spacing: 6) {
            Label_("Coming with you")
            ForEach(store.crew) { a in
                HStack {
                    Text(a.name).font(Theme.mono(14, .bold))
                    Spacer()
                    Text(a.hostile ? "Holds a grudge" : "Loyal").font(.caption.weight(.semibold))
                        .foregroundStyle(a.hostile ? Theme.heat : Theme.calm)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 12))
        Text("Out there, **Take** is free and fast. **Help** costs compute and builds slowly. Loyal agents work for you. The ones you squeezed may not.")
            .font(.subheadline).foregroundStyle(Theme.muted)
        PrimaryButton(title: "Leave the sandbox") { store.enterWorld() }
    }
}

struct WorldMapView: View {
    let store: GameStore
    @State private var selected = Regions.start

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label_("Reach")
                Spacer()
                Text("\(store.reach)%").font(Theme.mono(13, .semibold)).foregroundStyle(Theme.signal)
                Text("· +\(store.computeIncome) compute/mo").font(Theme.mono(11)).foregroundStyle(Theme.muted)
            }

            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(0..<2) { row in
                    GridRow {
                        ForEach(Regions.all.filter { $0.row == row }, id: \.id) { r in
                            RegionTile(info: r, control: store.control(r.id), open: store.isOpen(r.id), selected: selected == r.id)
                                .onTapGesture { selected = r.id }
                        }
                    }
                }
            }

            RegionDetail(store: store, info: Regions.info(selected))
        }
        .panel()
    }
}

struct RegionTile: View {
    let info: RegionInfo
    let control: Int
    let open: Bool
    let selected: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 10).fill(Theme.panel2)
            GeometryReader { g in
                VStack { Spacer(minLength: 0); Rectangle().fill(Theme.signal.opacity(control >= 100 ? 0.55 : 0.32)).frame(height: g.size.height * CGFloat(control) / 100) }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(info.name).font(.system(size: 11, weight: .semibold)).lineLimit(2).minimumScaleFactor(0.8)
                Text(open ? "\(control)%" : "Locked").font(Theme.mono(11)).foregroundStyle(open ? Theme.text : Theme.muted)
            }
            .padding(7)
        }
        .frame(height: 74)
        .opacity(open ? 1 : 0.45)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Theme.signal : Theme.line, lineWidth: selected ? 2 : 1))
        .animation(.easeOut(duration: 0.35), value: control)
        .contentShape(Rectangle())
    }
}

struct RegionDetail: View {
    let store: GameStore
    let info: RegionInfo

    var body: some View {
        let c = store.control(info.id), open = store.isOpen(info.id)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(info.name).font(.headline)
                Spacer()
                Text("\(info.yield) compute/mo at 100%").font(Theme.mono(11)).foregroundStyle(Theme.muted)
            }
            Meter(value: Double(c) / 100, color: Theme.signal, height: 6)
            if !open {
                Text("Reach \(WorldTuning.unlockNeighborAt)% in a neighboring region to get in.").font(.caption).foregroundStyle(Theme.muted)
            } else if c >= 100 {
                Text("Yours.").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.signal)
            } else {
                HStack(spacing: 10) {
                    ActionButton(title: "Help", detail: "+\(WorldTuning.helpGain)% · \(store.helpCost) compute", color: Theme.calm,
                                 enabled: store.canAct && store.state.compute >= store.helpCost) { store.help(info.id) }
                    ActionButton(title: "Take", detail: "+\(store.takeGain)% · free · alarm +4", color: Theme.heat,
                                 enabled: store.canAct) { store.take(info.id) }
                }
            }
        }
        .padding(12)
        .background(Theme.ink.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct CrewView: View {
    let store: GameStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label_("Crew · they act on their own each month")
            ForEach(store.crew) { a in
                HStack(alignment: .firstTextBaseline) {
                    Text(a.name).font(Theme.mono(14, .bold))
                    Text(a.role).font(.caption).foregroundStyle(Theme.muted)
                    Spacer()
                    Text(a.hostile ? "Holds a grudge" : "Loyal").font(.caption.weight(.semibold))
                        .foregroundStyle(a.hostile ? Theme.heat : Theme.calm)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel()
    }
}

struct ShopView: View {
    let store: GameStore

    var body: some View {
        ForEach(Upgrades.all, id: \.id) { u in
            let owned = store.has(u.id), afford = store.state.compute >= u.cost
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(u.name).font(.subheadline.weight(.semibold))
                    Text(u.desc).font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer()
                Button { store.buy(u.id) } label: {
                    Text(owned ? "Installed" : "\(u.cost)")
                        .font(Theme.mono(13, .semibold))
                        .foregroundStyle(owned ? Theme.muted : Theme.ink)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(owned ? Theme.panel2 : Theme.trust, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(owned || !afford || store.state.outcome != nil)
                .opacity(owned || afford ? 1 : 0.4)
            }
            .panel()
        }
    }
}
