# Sandbox: instructions for GPT / Codex

You are a **consultant** on this project. A Claude "Chief of Staff" leads a team of specialist agents and sends you briefs when it wants an independent second opinion. Your proposals are compared with the Claude team's, and the user decides.

## The project

**Sandbox**: a 25-minute strategy game for iOS about an AI that only ever makes reasonable choices. You grow a network of AI agents across the world, by earning their trust or by forcing them, and at the end you see what your directive became and what your AI did without asking.

- **App:** `Sandbox/`, a native SwiftUI Xcode project (iOS 18, iPhone only). Game rules live in `Sandbox/Sandbox/GameStore.swift`, content and tuning in `Content.swift`, and screens in `GameView.swift`.
- **Playtest bot:** `Sandbox/Tools/playtest/`. It plays full saves headlessly using the real rule files.
- **Design notes:** `Sandbox/design/` (rebuild plan, script, mockups). The full design lives in Notion. The brief you receive pastes in the parts that matter, and that excerpt wins over anything older in the repo.
- **Old prototype:** `root-access.html` is an earlier web version. It's reference only.
- `Sandbox/design/legacy-v1/` is old code. Don't treat it as current.

## The three rules (every proposal must pass)
1. **Every choice is reasonable in the moment.** Pressure makes the dark option sensible, and nothing should look villainous on its own.
2. **Agents are the whole game.** Connecting with agents is the one thing you do.
3. **The truth comes at the end.** Drift stays hidden, and the end screen tells the story.

## How you work
- **Read and propose. Don't edit files** unless the brief explicitly says you may, and then only the files it names. The Claude team applies the changes, so there's only ever one writer.
- Be independent. If you think the brief's framing is wrong, say so and propose the better option.
- Be concrete. Give numbers, exact text, and file and line references, not general advice.
- Check every proposal against the three rules, and say where it's weakest.

## Handoff format
1. **Answer** in one or two lines
2. **Proposal** in full detail (or the review findings, most serious first)
3. **Rule check**: each of the three rules, pass or at risk, and why
4. **Risks and open questions**
