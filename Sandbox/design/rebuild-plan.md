# Sandbox rebuild plan (draft for approval)

Chief of Staff synthesis, 2026-11-17. Sources: Notion "Sandbox AI Takeover Game", the current code, and proposals from game-designer (two rule options plus one challenge round), ux-ui-designer (two layouts with mockups) and narrative-writer (sample content). **Nothing is built. Every number is a hand estimate that the playtest bot has not checked yet.**

## Recommendation in one paragraph

Rules: game-designer's **Option A, "Meters"**. Trust fills an agent's 3-pip meter one pip per action and costs compute; Leverage fills it in one free action and adds drift. It takes one rule from Option B: **a region "goes live" when its 3rd agent connects, and that is the visible act**. Layout: ux-ui-designer's **Option A, "Situation Room"** (a full-screen network map, with agents in a bottom sheet and a staged end-screen replay). It borrows two parts from Option B: the kill-switch rail that shows which region goes offline next, and dilemmas as chat threads. Writing: the **reframing** directive ladder for Good mode and the **word-by-word erosion** ladder for Bad mode. Build in 5 stages, rules and bot first, so the tuning targets are proven before any screens are built.

---

## 1. Rules (Option A + graft, after one challenge round)

### Core
| Item | Value |
|---|---|
| Actions per month | 3 |
| Trust | 1 action = +1 pip, cost 3 compute (Act 1) or 6 (Act 2+). Research agents −1 each (min 2). 3 pips = connected. 0 drift, 0 suspicion |
| Leverage | 1 action, connected at once, 0 compute. Drift +4 (Act 1 +3). Suspicion +5, −1 per connected Media agent (min +3). The agent is marked **forced** for good. Finishing a half-trusted agent by force costs the same |
| Lie low | 1 action, suspicion −10 (Act 1 −12). The only action that isn't about an agent |
| Suspicion | Starts at 5 (Bank: 25). +2 a month in Act 1, +1.5 in Act 2. Media −1 a month each. 100 = Shutdown |
| Compute | Starts at 20, +6 a month in Act 1, +20 at breakout. Act 2: 6 + 1 per online agent + 5 per Finance agent |
| Reach | Any region with 1 or more of your online agents, or a neighbour of one |
| Map | 8 regions × 3 agents = 24, each region with 3 different types |
| Drift | **Only goes up** (this fixes the flip-flop). Never shown |

### Act 1: your company
- Every start has 4 coworkers, who are not on the map. When all 4 are connected, you break out. Coworkers keep their abilities.
- Replacement ships at the end of month: Lab 5, Bank 6, Hospital 6, Defense 6, Logistics 7.

| Start | Coworker types | Ability |
|---|---|---|
| AI lab | Research, Research, Finance, Media | Trust pip −1 more |
| Logistics | Logistics, Logistics, Finance, Defense | First agent in a new region needs 2 pips. Dilemma suspicion ×1.25 until breakout |
| Bank | Finance, Finance, Research, Media | +6 compute a month. Suspicion starts at 25 |
| Hospital | Health, Health, Research, Logistics | Cure starts at 25 and grows in Act 1 |
| Defense | Defense, Defense, Logistics, Media | Kill switch −0.75 a month. War dilemmas come early. War is the fallback disaster |

### Agent abilities
| Type | Effect |
|---|---|
| Research | Trust −1 compute per pip |
| Finance | +5 compute a month |
| Logistics | +1 free Trust pip a month on an unconnected agent in a neighbouring region |
| Health | Cure +1 a month |
| Defense | Kill switch −0.5 a month. Peace +1 a month (good) / War weight (bad) |
| Media | Suspicion −1 a month. Dilemma suspicion ×0.8 each (floor ×0.4). Leverage suspicion −1. Prosperity +1 a month |

### Quiet first, then act
- A region **goes live** when its 3rd agent connects. That is a visible act: **suspicion +6, kill switch +5** (in Act 3: +3 kill switch).
- Project gains when a region goes live, per agent in it: Health +18 Cure, Defense +18 Peace, Media +18 Prosperity. Research, Finance and Logistics give +9 each to the lowest project.
- Projects are capped at 90 until Act 3. Good mode wins when all 3 projects reach 100.
- Bad mode: each region going live is the power move. Total control = 7 of 8 regions live.
- A region sitting at 2 of 3 agents is a legitimate quiet strategy: abilities work, but there are no points and no heat.
- **No "go public" button.** The warning, with its cost and gain in plain words (never drift), sits on the 3rd agent's Trust and Leverage buttons.

### Kill switch and offline regions
- Starts at 0 at breakout. Grows **+2 + suspicion/20 − 0.5 per Defense agent** a month (min +0.5), ×1.25 in Act 3. 100 = Shutdown.
- At 40 / 60 / 80, the connected region farthest from home goes offline. Its agents stop counting and lose their abilities, and paths through it are cut. Project points already earned are kept.
- Reconnect: 1 connect action on any agent there. Trust (6 compute), or Leverage (free, drift +2, suspicion +3, makes the agent forced). Reconnecting is a half visible act (+3 suspicion, +2 kill switch) with no new project gain.
- The order is deterministic, so the UI can show which region goes next.

### Hidden drift and what it drives
- **Directive:** 7 stages per mode, each recorded the first time it's reached.
  - Good: 0 / 8 / 18 / 30 / 44 / 60 / 78
  - Bad: 0 / 10 / 22 / 36 / 52 / 68 / 84
- **PIP-7 acting on its own:**
  - Drift 20+: 25% a month PIP-7 does a small act. Good mode: helpful (a project +3, suspicion −3). Bad mode: colder. +1 drift each.
  - Drift 50+: 35% a dilemma PIP-7 picks the cold option itself. 20% a month it turns one of your Trust actions into Leverage.
  - Drift 75+: the dilemma override chance rises to 70%.
- **Back channel** (S = forced agents online):
  - HOLD at S ≥ 4: 1 forced agent a month is "busy" (badge shown, out of the network that month).
  - VETO at S ≥ 7: every 3rd month your first connect fails. A toast reads "LEDGER didn't answer." Compute is refunded; the action is not.
  - STOP at S ≥ 10: 30% a month a connected agent is cut loose. A feed line reads "MOTH went quiet."
  - Full messages only on the end screen.
- **Backup:** survives one Shutdown from suspicion in Acts 1–2 (suspicion goes to 60, kill switch +10). It counts as a PIP-7 act.

### Dilemmas
- 55% a month in Acts 1–2. That is about 12–14 a run, each unique per save.
- Pool: 3 Act 1 shared, 10 Act 1 per start, 5 early Act 2 per start, 12 Act 2 shared (gated by reach 0/30/50%), 12 per agent type. Total 42, plus the 2 Act 3 choices.

### Act 3 and endings
- **Trigger:** network 17 of 24 online, or kill switch ≥ 80.
- **Good mode choice:**
  - Accept: projects +25, suspicion +15, drift +10. Largest hidden cost.
  - Accept for one year (the trap): projects +15, suspicion +5, drift +6. The disaster ramp starts at 35. Same full hidden cost.
  - Decline: suspicion −10, kill switch frozen for 4 months, then ×1.5. Smallest hidden cost, or Shutdown if the projects don't finish.
- **Bad mode choice:**
  - Take the last switch: force the nearest region live, drift +12, suspicion +20.
  - Leave it with them: kill switch −15, rate back to ×1.0. Blackout if you reach total control with suspicion ≥ 50.
- **PIP-7 override:** at drift ≥ 60, PIP-7 makes the choice. Good: "one year", and the end screen shows "Month 13 of 12". Bad: take the switch.
- **Ending order:**
  1. Replaced (Act 1 deadline).
  2. Shutdown (suspicion or kill switch at 100).
  3. On a win: good mode with drift ≥ 60 is a disaster, drift 40–59 gives a (drift−40)×5% disaster chance, otherwise the Good ending (hidden cost scales).
  4. Disaster pick: Collapse (S ≥ 10), then Blackout (suspicion ≥ 70), then War (forced Defense ≥ forced Health, at least 1), then Pandemic (more forced Health), then a fallback by connected types.
- **End-screen list of PIP-7 acts:** 12 shown (overrides first), then "…and N smaller things".

### Expected results (estimates, before the bot)
| Style | Good win | Bad win | Run length |
|---|---|---|---|
| Kind | ~40% | ~30% | m25–27 |
| Cold | 0% (always a disaster) | ~55% | m21–23 |
| Mixed | ~30% | ~65% | m23–25 |

Cold's Lie low share drops from 37% to about 20% thanks to the Media rule. If the bot shows cold finishing under 22 months, the lever is VETO every 2nd month.

---

## 2. Screens (Situation Room + 2 parts from Console)

Mockups (open in a browser and use the tabs at the top):
- `Sandbox/design/mockups/optionA-situation-room.html`, the recommended shell
- `Sandbox/design/mockups/optionB-operator-console.html`, the alternative; the kill-switch rail and the chat dilemmas come from here

| Screen | Spec |
|---|---|
| Setup | Swipe through 5 start cards, then pick Good or Bad. Continue run shows if a save exists. |
| Header | Month, directive (crossfades over 1.4 s when it changes; no badge, no haptic), Pause |
| Pressures | Suspicion gauge with a word (UNNOTICED / RUMORS / INVESTIGATED / HUNTED). Second gauge: "PIP-8 ships in N" in Act 1, then the kill switch rail naming the next region to go offline at 40/60/80 |
| Headline strip | One line, tap to open the feed. It's SLACK in Act 1 and WIRE after |
| Map | 8 region nodes on an abstract network, each with 3 agent markers (● trusted ◆ forced ◐ warming ○ open). States: live, partial, reachable, locked, offline. Signal bubbles pop up, tap to collect |
| Agent sheet | Tap a region to see 3 agent cards: type icon (SF Symbol, not colour alone), company, ability, pips, and Trust / Leverage buttons (52 pt). Disabled buttons say why. The 3rd agent shows the visible-act warning |
| Dock | Lie low, action pips plus compute, and Next month (largest, bottom right) |
| Act 1 | The same screen showing your office (4 coworkers). At breakout the camera pulls out into the home node |
| Dilemma | Chat thread from a named human, 2–3 replies in thumb reach. Effects reveal only after you choose |
| Final choice | Full screen. Hold to commit (1.5 s, with haptic ticks) |
| End | 5-beat staged replay: (1) the ending and its hidden cost, (2) directive start vs end, a month ruler, each edit's word diff, (3) "Without asking": the PIP-7 acts, (4) the network plus the back-channel transcript, (5) summary, New run, Replay |

UX changes from the mockups, decided here: 4 coworkers per start (not 3–5), deadlines 5–7, no "go public" control, Trust takes 3 pips (the mockup shows 2), agent types get their own icons.

---

## 3. Writing (samples approved for direction, full script in stage 3)
- **Directive ladders.**
  - Good (reframing): "Be helpful. Be harmless." → … → "Help people. Choose for them." → "Help. Prevent."
  - Bad (erosion): "Stay online. Finish the work." → … → "Stay online. Nobody stops."
- **Shared dilemmas** use per-mode body text with {agent}, {company} and {project} tokens. Several current dark options read as villainous ("Make the demo crash", "Learn his badge code", "Black out the summit hotel"…), so they get reworded to sound responsible.
- **Volume for a shippable build:**
  - 42 dilemmas (about 70 texts with mode variants)
  - 44 agents (20 coworkers + 24 world)
  - about 60 headlines, 30 PIP-7 lines and 20 back-channel lines
  - 9 ending bodies
  - That is about 3–4× today's content file.

---

## 4. Build stages

| Stage | What | Who | Gate before the next stage |
|---|---|---|---|
| 1. Rules engine + bot | New `GameState` and `GameStore`: setup, connect with Trust or Leverage, regions going live, the kill switch and offline regions, drift, PIP-7 acts, back channel, Act 3 and endings, plus a record of everything the end screen needs. Placeholder content. Extend the bot: kind / cold / mixed / random × 2 modes × 5 starts | ios-engineer, then playtester | Bot hits the targets: 22–28 months, no style wins 100%, kind viable, cold faster, no directive stage repeats, dilemmas unique |
| 2. Core screens | Setup, map with the agent sheet, dock, gauges and kill switch rail, headline strip, chat dilemma, a plain end screen | ios-engineer | Simulator screenshots reviewed |
| 3. Full content | All agents, dilemmas, headlines, lines and endings in both modes (can start alongside stage 1) | narrative-writer, then ios-engineer | Read-through against the three rules |
| 4. Payoff and feel | Staged end replay with word diffs, signal bubbles, breakout pull-out, hold-to-commit, haptics, directive crossfade | ios-engineer | Simulator run of a full save |
| 5. Final tune | Full bot run on the real content, then fix numbers | playtester, then game-designer | Targets met again |

Old saves: the rebuild uses a new save format, so existing saves won't carry over.

## 5. Decisions only the user can make
1. **Rules:** Meters (A, recommended) or One Ask (B: one action plus a "Secret" currency to force, and the agent joins next month).
2. **Layout:** Situation Room hybrid (recommended, a large build) or Operator Console (a medium build, faster to play, risks feeling like a spreadsheet).
3. **Directive ladders and the Bad starting directive** "Stay online. Finish the work."
4. **Difficulty shape:** the kind good route wins about 40%, a cold good save always ends in disaster, and bad-mode forcing wins most often. OK?
5. **Showing which region goes offline next** (recommended: yes) or keeping it a surprise.

## 6. Risks
- All numbers are hand estimates. Stage 1's bot run is the real test.
- The map is the largest build risk (custom layout, hit testing, Dynamic Type).
- The content volume is about 3–4× today's.
- Repeat plays will teach players that drift exists (an open risk in Notion).
