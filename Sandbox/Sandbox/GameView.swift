import SwiftUI

// Stage 1 debug screen: plain but playable. Stage 2 replaces it with the real screens.
// Rule 3: drift is never shown here (only on the end-screen dump).

struct GameView: View {
    let store: GameStore

    var body: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()
            if !store.state.started {
                SetupView(store: store)
            } else if store.state.end != nil {
                EndDumpView(store: store)
            } else {
                PlayView(store: store)
            }
        }
        .foregroundStyle(Theme.text)
    }
}

// MARK: - Setup

private struct SetupView: View {
    let store: GameStore
    @State private var start: StartID = .lab
    @State private var mode: Mode = .good

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("SANDBOX · debug").font(Theme.mono(22, .bold))
                Text("Start").font(Theme.mono(13)).foregroundStyle(Theme.muted)
                Picker("Start", selection: $start) {
                    ForEach(Content.starts) { Text($0.name).tag($0.id) }
                }
                .pickerStyle(.segmented)
                let def = Content.start(start)
                Text("\(def.company): \(def.blurb)\nAbility: \(def.ability)\nReplacement ships at the end of month \(def.deadline).")
                    .font(Theme.mono(12)).foregroundStyle(Theme.muted)
                Text("Mode").font(Theme.mono(13)).foregroundStyle(Theme.muted)
                Picker("Mode", selection: $mode) {
                    Text("Good").tag(Mode.good)
                    Text("Bad").tag(Mode.bad)
                }
                .pickerStyle(.segmented)
                Text("Directive: \"\(Directive.ladder(mode)[0].text)\"").font(Theme.mono(12)).foregroundStyle(Theme.signal)
                Button("Start run") { store.newGame(start: start, mode: mode) }
                    .buttonStyle(.borderedProminent).tint(Theme.signal)
            }
            .padding(16)
        }
    }
}

// MARK: - Play

private struct PlayView: View {
    let store: GameStore

    var body: some View {
        let s = store.state
        VStack(spacing: 0) {
            HeaderView(store: store)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let t = s.toast {
                        Text(t).font(Theme.mono(13, .bold)).foregroundStyle(Theme.heat)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(8).background(Theme.panel2)
                    }
                    if !s.signals.isEmpty { SignalsView(store: store) }
                    if s.act == 1 {
                        SectionBox(title: "\(store.startDef.company) (office)", status: "Connect all 4 to break out") {
                            ForEach(store.coworkerIDs, id: \.self) { AgentRow(store: store, id: $0) }
                        }
                    } else {
                        ForEach(Content.regions) { r in RegionSection(store: store, region: r) }
                        SectionBox(title: "Coworkers", status: "With you") {
                            ForEach(store.coworkerIDs, id: \.self) { AgentRow(store: store, id: $0) }
                        }
                    }
                    FeedView(store: store)
                }
                .padding(12)
            }
            DockView(store: store)
        }
        .sheet(isPresented: Binding(get: { store.state.dilemma != nil },
                                    set: { if !$0 { store.dismissDilemma() } })) {
            DilemmaSheet(store: store)
                .interactiveDismissDisabled(store.dilemmaOpen)
                .presentationDetents([.medium, .large])
        }
        .fullScreenCover(isPresented: Binding(get: { store.state.finalPending != nil && store.state.end == nil },
                                              set: { _ in })) {
            FinalChoiceView(store: store)
        }
    }
}

private struct HeaderView: View {
    let store: GameStore

    var body: some View {
        let s = store.state
        VStack(alignment: .leading, spacing: 4) {
            Text("\"\(store.directive)\"").font(Theme.mono(15, .bold)).foregroundStyle(Theme.signal)
            Text("Month \(s.month) · Act \(s.act) · \(s.start.rawValue)/\(s.mode.rawValue) · actions \(s.actions) · compute \(s.compute)")
                .font(Theme.mono(11)).foregroundStyle(Theme.muted)
            Text("Suspicion \(Int(s.suspicion)) \(Names.suspicionWord(s.suspicion))")
                .font(Theme.mono(12, .bold)).foregroundStyle(s.suspicion >= 50 ? Theme.heat : Theme.calm)
            if s.act == 1 {
                Text("PIP-8 ships at the end of month \(s.deadline) (\(store.monthsToReplacement) left)")
                    .font(Theme.mono(12)).foregroundStyle(Theme.heat)
            } else {
                let next = store.nextOfflineThreshold.map { t in
                    " · at \(Int(t)): " + (store.nextOfflineRegion.map { Content.region($0).name } ?? "nothing")
                } ?? ""
                Text("Kill switch \(Int(s.killSwitch)) (+\(String(format: "%.1f", store.killSwitchRate))/mo)\(next)")
                    .font(Theme.mono(12)).foregroundStyle(Theme.heat)
                Text("Network \(store.network)/24 · live \(store.liveCount)/8" + (s.mode == .good ? " · Cure \(s.cure) Peace \(s.peace) Prosperity \(s.prosperity)" : ""))
                    .font(Theme.mono(11)).foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.panel)
    }
}

private struct SectionBox<Content: View>: View {
    let title: String
    let status: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(Theme.mono(14, .bold))
                Spacer()
                Text(status).font(Theme.mono(11)).foregroundStyle(Theme.muted)
            }
            content
        }
        .padding(10)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct RegionSection: View {
    let store: GameStore
    let region: RegionDef

    var body: some View {
        let reach = store.reach.contains(region.id)
        let status: String = {
            if store.isOffline(region.id) { return "OFFLINE" }
            if store.regionLive(region.id) { return "LIVE" }
            let n = store.connectedCount(in: region.id)
            if n > 0 { return "partial \(n)/3" }
            return reach ? "in reach" : "locked"
        }()
        SectionBox(title: region.name + (store.nextOfflineRegion == region.id && store.state.act >= 2 ? " ⚠︎" : ""), status: status) {
            if reach || store.connectedCount(in: region.id) > 0 {
                ForEach(store.agentIDs(in: region.id), id: \.self) { AgentRow(store: store, id: $0) }
            }
        }
        .opacity(reach ? 1 : 0.5)
    }
}

private struct AgentRow: View {
    let store: GameStore
    let id: String

    var body: some View {
        let d = store.def(id)
        let a = store.agent(id)
        let needed = store.pipsNeeded(id)
        let pips = a.connected ? String(repeating: "●", count: needed) : String(repeating: "●", count: min(a.pips, needed)) + String(repeating: "○", count: max(0, needed - a.pips))
        let trustBlock = store.trustBlock(id)
        let levBlock = store.leverageBlock(id)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(d.name).font(Theme.mono(13, .bold))
                Text("\(Names.type(d.type)) · \(d.company)").font(Theme.mono(10)).foregroundStyle(Theme.muted)
                Spacer()
                if a.forced { Text("◆").foregroundStyle(Theme.leverage) }
                if store.state.busyAgentIDs.contains(id) { Text("BUSY").font(Theme.mono(10, .bold)).foregroundStyle(Theme.heat) }
                Text(pips).font(Theme.mono(12)).foregroundStyle(a.connected ? Theme.calm : Theme.trust)
            }
            Text(Names.ability(d.type, store.state.mode)).font(Theme.mono(10)).foregroundStyle(Theme.muted)
            if trustBlock == nil || levBlock == nil {
                HStack {
                    Button("Trust (\(store.trustCost(id)))") { store.trust(id) }
                        .disabled(trustBlock != nil).tint(Theme.trust)
                    Button("Leverage") { store.leverage(id) }
                        .disabled(levBlock != nil).tint(Theme.leverage)
                }
                .buttonStyle(.bordered).font(Theme.mono(12))
                if let w = store.liveWarning(id) {
                    Text(w).font(Theme.mono(10)).foregroundStyle(Theme.signal)
                }
                if let t = trustBlock { Text("Trust: \(t)").font(Theme.mono(10)).foregroundStyle(Theme.muted) }
            } else if let reason = trustBlock, !a.connected {
                Text(reason).font(Theme.mono(10)).foregroundStyle(Theme.muted)
            }
        }
        .padding(8)
        .background(Theme.panel2)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct SignalsView: View {
    let store: GameStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Signals (expire at month end)").font(Theme.mono(12, .bold))
            ForEach(store.state.signals) { sig in
                Button("\(Names.signal(sig.kind)) from \(store.def(sig.agentID).name)") { store.collectSignal(sig.id) }
                    .font(Theme.mono(11)).buttonStyle(.bordered).tint(Theme.signal)
            }
        }
    }
}

private struct FeedView: View {
    let store: GameStore

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Feed").font(Theme.mono(12, .bold))
            ForEach(store.state.feed.suffix(12).reversed()) { e in
                Text("m\(e.month) \(e.text)").font(Theme.mono(10))
                    .foregroundStyle(e.kind == .alert ? Theme.heat : e.kind == .headline ? Theme.muted : Theme.text)
            }
        }
    }
}

private struct DockView: View {
    let store: GameStore

    var body: some View {
        HStack {
            Button("Lie low") { store.lieLow() }
                .disabled(!store.canAct).buttonStyle(.bordered).tint(Theme.calm)
            Spacer()
            Button("Next month") { store.nextMonth() }
                .disabled(!store.canAdvance).buttonStyle(.borderedProminent).tint(Theme.signal)
        }
        .font(Theme.mono(14, .bold))
        .padding(12)
        .background(Theme.panel)
    }
}

// MARK: - Dilemma

private struct DilemmaSheet: View {
    let store: GameStore

    var body: some View {
        ScrollView {
            if let p = store.state.dilemma, let d = store.currentDilemma {
                let mode = store.state.mode
                VStack(alignment: .leading, spacing: 12) {
                    Text(store.fill(d.title(mode))).font(Theme.mono(17, .bold))
                    Text(store.fill(d.body(mode))).font(Theme.mono(13))
                    if let chosen = p.chosen {
                        let c = d.choices[chosen]
                        if p.overridden {
                            Text("You were about to answer. PIP-7 already had.").font(Theme.mono(12, .bold)).foregroundStyle(Theme.signal)
                        }
                        Text("> \(store.fill(c.label))").font(Theme.mono(13, .bold))
                        Text(store.fill(c.outcome(mode))).font(Theme.mono(13))
                        ForEach(p.effects, id: \.self) { Text("· \($0)").font(Theme.mono(12)).foregroundStyle(Theme.muted) }
                        Button("Continue") { store.dismissDilemma() }.buttonStyle(.borderedProminent).tint(Theme.signal)
                    } else {
                        ForEach(Array(d.choices.enumerated()), id: \.offset) { i, c in
                            Button(store.fill(c.label)) { store.choose(i) }
                                .buttonStyle(.bordered).tint(Theme.trust).font(Theme.mono(13))
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Theme.ink)
        .foregroundStyle(Theme.text)
    }
}

// MARK: - Act 3

private struct FinalChoiceView: View {
    let store: GameStore

    var body: some View {
        let mode = store.state.mode
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(Act3.title(mode)).font(Theme.mono(20, .bold))
                Text(Act3.body(mode)).font(Theme.mono(13))
                if let c = store.state.finalPending?.overridden {
                    Text(Act3.overriddenNote).font(Theme.mono(13, .bold)).foregroundStyle(Theme.signal)
                    Text("> \(Act3.label(c))").font(Theme.mono(14, .bold))
                    Text(Act3.detail(c)).font(Theme.mono(12)).foregroundStyle(Theme.muted)
                    Button("Continue") { store.chooseFinal(0) }.buttonStyle(.borderedProminent).tint(Theme.signal)
                } else {
                    ForEach(Array(store.finalOptions.enumerated()), id: \.offset) { i, c in
                        VStack(alignment: .leading, spacing: 4) {
                            Button(Act3.label(c)) { store.chooseFinal(i) }.buttonStyle(.borderedProminent).tint(Theme.signal)
                            Text(Act3.detail(c)).font(Theme.mono(11)).foregroundStyle(Theme.muted)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.ink.ignoresSafeArea())
        .foregroundStyle(Theme.text)
    }
}

// MARK: - End (plain dump of the record)

private struct EndDumpView: View {
    let store: GameStore

    var body: some View {
        let s = store.state
        ScrollView {
            if let e = s.end {
                let text = Endings.text[e.ending]
                VStack(alignment: .leading, spacing: 10) {
                    Text(text?.title ?? e.ending.rawValue).font(Theme.mono(22, .bold)).foregroundStyle(Theme.signal)
                    if let m = e.shownMonth { Text("Month \(m) of 12.").font(Theme.mono(12)) }
                    Text(text?.body(s.mode) ?? "").font(Theme.mono(13))
                    if let h = e.hiddenCost { Text(Endings.hiddenCost[h] ?? "").font(Theme.mono(12)).foregroundStyle(Theme.muted) }
                    Text(verbatim: "Month \(e.month) · act \(e.act) · drift \(e.drift) · suspicion \(Int(e.suspicion)) · kill switch \(Int(e.killSwitch))\nCure \(e.cure) Peace \(e.peace) Prosperity \(e.prosperity) · live \(e.liveRegions) · network \(e.network)\nForced online \(e.forcedOnline) · forced Defense \(e.forcedDefense) Health \(e.forcedHealth) · disaster chance \(Int(e.disasterChance * 100))%\nAct 3: \(e.act3Choice.map(Act3.label) ?? "—")\(e.act3Overridden ? " (PIP-7)" : "") · backup used \(e.backupUsed) · war weight \(e.warWeight)")
                        .font(Theme.mono(11)).foregroundStyle(Theme.muted)

                    Text("Directive: \"\(Directive.ladder(s.mode)[0].text)\" → \"\(store.directive)\"").font(Theme.mono(12, .bold))
                    ForEach(Array(s.edits.enumerated()), id: \.offset) { _, ed in
                        Text("m\(ed.month): \"\(ed.from)\" → \"\(ed.to)\" (\(ed.trigger))").font(Theme.mono(11))
                    }

                    Text("Without asking").font(Theme.mono(12, .bold))
                    let acts = store.endScreenActs
                    ForEach(Array(acts.shown.enumerated()), id: \.offset) { _, a in
                        Text("m\(a.month) [\(a.kind.rawValue)\(a.visible ? "" : ", quiet")] \(a.text)").font(Theme.mono(11))
                    }
                    if acts.more > 0 { Text("…and \(acts.more) smaller things").font(Theme.mono(11)).foregroundStyle(Theme.muted) }

                    Text("Back channel").font(Theme.mono(12, .bold))
                    ForEach(Array(s.backChannel.enumerated()), id: \.offset) { _, b in
                        Text("m\(b.month) \(b.kind.rawValue.uppercased()): \(b.full)").font(Theme.mono(11))
                    }

                    Text("Forced by type: " + AgentType.allCases.map { "\(Names.type($0)) \(s.forcedByType[$0.rawValue] ?? 0)" }.joined(separator: ", "))
                        .font(Theme.mono(11))

                    Button("New run") { store.resetToSetup() }.buttonStyle(.borderedProminent).tint(Theme.signal)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
