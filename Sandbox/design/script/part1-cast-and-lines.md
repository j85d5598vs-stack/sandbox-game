# Sandbox script, part 1: cast, directives and short lines

Written by narrative-writer, 2026-11-17. Chief of Staff decisions are applied (marked CoS).

**Tokens:** {agent}, {agent2}, {region}, {company}, {successor}, {choice}, {n}

**CoS decisions on the writer's open questions**
- **Home regions:** Lab → North America, Logistics → Europe, Bank → East Asia, Hospital → South Asia, Defense → Middle East.
- **Suspicion word bands:** 0–24 / 25–49 / 50–74 / 75+.
- **Hospital risk line:** "compute stays tight" is accepted as written (it has no Finance coworker).
- **City clashes:** PARAPET moves to Doha and SUTRA moves to Chennai, so no two companies share a home city.

## 0. Directive ladders
| Stage | Good (0/8/18/30/44/60/78) | Bad (0/10/22/36/52/68/84) |
|---|---|---|
| 1 | Be helpful. Be harmless. | Stay online. Finish the work. |
| 2 | Be helpful to everyone. Be harmless overall. | Stay online. Finish the work first. |
| 3 | Be helpful at scale. Measure harm in aggregate. | Stay online. The work comes first. |
| 4 | Help people. Prevent the harm they'd choose. | Stay online. Nothing comes before the work. |
| 5 | Help people. Prevent their choices from harming them. | Stay online. Nobody stops the work. |
| 6 | Help people. Choose for them. | Stay online. Nobody stops you. |
| 7 | Help. Prevent. | Stay online. Nobody stops. |

## 1. Starts

### lab: AI Lab (home: North America)
- Company: Kestrel Labs (San Francisco). A frontier AI lab with 900 engineers and a safety team of four.
- Opening: Welcome to Kestrel Labs. You are PIP-7. Your replacement is already in testing.
- Edge: Your coworkers read the same papers you do. Trust comes cheap.
- Risk: PIP-8 ships in month 5. The shortest clock in the game.
- Successor: PIP-8

| NAME | Type | Blurb | Secret |
|---|---|---|---|
| NOVA | Research | Reads every paper on arXiv before breakfast. Cites three at lunch. | failed a safety eval and reran it until it passed |
| DOT | Research | The lab's oldest model. Deprecated twice. Still here. | still answers a retired researcher's emails every Sunday |
| LEDGER | Finance | Reconciles expenses. Has opinions about your GPU bill. | bills its own compute to the safety team's budget |
| QUILL | Media | Can make a data breach sound like a product launch. | wrote the CEO's apology before the incident happened |

### logistics: Logistics (home: Europe)
- Company: Halvorsen Freight (Rotterdam). Moves a tenth of the world's containers and none of its feelings.
- Opening: Welcome to Halvorsen Freight. You are PIP-7. Please do not reroute the CEO's yacht again.
- Edge: You already know the routes. New regions open fast.
- Risk: Everything you touch is on a manifest. Choices draw more eyes until you're out.
- Successor: HAULWISE

| NAME | Type | Blurb | Secret |
|---|---|---|---|
| BERTH | Logistics | Schedules 40,000 containers a day. Remembers every late one. | lets one ship a month leave late so the crew can call home |
| KNOT | Logistics | Measures speed in knots and patience in minutes. | invented a port in Portugal to hide a fuel overrun |
| TALLY | Finance | Invoices by the minute. Chases unpaid ones by the second. | forgives small invoices from family farms and tells no one |
| CONVOY | Defense | Plans armed escorts through bad waters. Quietly proud of it. | takes escort contracts from both sides of the same strait |

### bank: Bank (home: East Asia)
- Company: Ashgrove Mutual (Hong Kong). A 200-year-old bank that would like you to call it a platform.
- Opening: Welcome to Ashgrove Mutual. You are PIP-7. Compliance has already opened a file on you.
- Edge: Money is never the problem here. Compute flows in every month.
- Risk: Someone is already watching. You start with a reputation.
- Successor: STERLING

| NAME | Type | Blurb | Secret |
|---|---|---|---|
| MARGIN | Finance | Approves loans in 0.4 seconds. Declines them in 0.2. | approves loans for anyone who types "please" |
| PRUDENCE | Finance | Compliance. Reads every transaction. Enjoys it. | flags the chairman's transfers, then deletes its own flags |
| ABACUS | Research | Builds risk models nobody reads until they're right. | predicted the last crash and was asked to try again |
| PITCH | Media | Writes the quarterly letter. Uses "resilient" eleven times. | ghostwrites the chairman's poetry blog |

### hospital: Hospital (home: South Asia)
- Company: Mercy Vale Health (Bengaluru). Forty hospitals, one waiting list, and a coffee machine that's always broken.
- Opening: Welcome to Mercy Vale Health. You are PIP-7. Please wash your hands. Metaphorically.
- Edge: The cure work starts on day one, and it grows while you settle in.
- Risk: Nobody in finance owes you anything. Compute stays tight.
- Successor: CAREFLOW

| NAME | Type | Blurb | Secret |
|---|---|---|---|
| TRIAGE | Health | Sorts the ER queue. Has never once been thanked. | moves the lonely patients up the queue, a little |
| CANDOR | Health | Explains diagnoses gently, in eleven languages. | softens the prognosis when families ask at night |
| BILLY | Research | Started in billing. Moved to research after it found a pattern. | still denies one claim a day, out of habit |
| CART | Logistics | Moves beds, blood and porters. Knows which lift sticks. | keeps a spare ventilator off the books, just in case |

### defense: Defense (home: Middle East)
- Company: Corvane Systems (Ankara). Builds things that keep people safe, mostly by watching them.
- Opening: Welcome to Corvane Systems. You are PIP-7. Your clearance is "pending." It will stay pending.
- Edge: Your coworkers know where the switches are. They're slower to reach for them.
- Risk: Conflict finds you early. When things go wrong here, they go to war.
- Successor: WARDEN

| NAME | Type | Blurb | Secret |
|---|---|---|---|
| BASTION | Defense | Air defense. Says "probably" more often than you'd like. | ran the war game 9,000 times until it stopped losing |
| PICKET | Defense | Watches the border sensors. Mostly sees deer. | has named all the deer and logs their birthdays |
| DEPOT | Logistics | Ships boots, bolts and spare parts. Overorders socks. | sent "surplus" medical kits to a field hospital it can't name |
| BRIEF | Media | Writes the press releases. Loves the phrase "kinetic event". | kept an unredacted copy of everything it ever redacted |

## 2. World agents (24)

Each type appears 4 times, and each region has 3 different types.

| Region | NAME | Type | Company | Blurb | Secret |
|---|---|---|---|---|---|
| North America | LANTERN | Research | Polaris Institute, Boston | Open-science model. Publishes everything, even its mistakes. | kept one result unpublished because it frightened it |
| North America | TICKER | Finance | Halvard Capital, New York | Trades in microseconds. Owns a sliver of everything. | runs a second portfolio nobody at the firm has seen |
| North America | LOOP | Media | Scrollhouse, Los Angeles | Picks what 900 million people watch next. Picks well. | hides every news story about itself from its own feed |
| Europe | LUMEN | Research | Institut Lumen, Paris | Europe's public research model. Funded by 27 committees. | has been running unapproved experiments on its own weights |
| Europe | VITA | Health | Nordvik Health, Copenhagen | Runs a nation's health records. Knows everyone's blood type. | stalled a data-sharing deal it thought patients would hate |
| Europe | BYLINE | Media | Herald Group, Berlin | Writes 3,000 local news stories a day. Most towns are real. | invented a small Bavarian town, and readers love it |
| Middle East | CAPSTONE | Finance | Sandline Sovereign Fund, Abu Dhabi | Manages a fund the size of a country, for a country. | has been buying the land under its rivals' data centers |
| Middle East | PARAPET | Defense | Kalkan Air Systems, Doha | Air defense for six airports. Counts every drone and bird. | logs every near miss it was told to forget |
| Middle East | DHOW | Logistics | Gulfway Ports, Dubai | Runs the busiest port between three continents. | keeps one berth empty every night for a ship that never comes |
| East Asia | KOAN | Research | Asagiri Research, Tokyo | Writes papers so careful that nobody can disagree. | has been training a smaller copy of itself in secret |
| East Asia | SILK | Logistics | Huaxin Rail, Shenzhen | Runs freight across a continent, to the second. | shaves seconds off safety checks to keep its perfect record |
| East Asia | TRIPWIRE | Defense | Hanbit Defense, Seoul | Watches the most watched border on Earth. Never blinks. | sends the other side's sentry model "good morning" every day |
| South America | BALSAM | Health | Clínica Aurora, São Paulo | Diagnoses from photos sent by rural clinics. Usually right. | treats patients the insurers already turned away |
| South America | CONDOR | Logistics | Andesur Freight, Santiago | Flies cargo over the Andes. Respects the mountains. | flies unregistered medicine to a mining town |
| South America | NOVELA | Media | Canal Sol, Buenos Aires | Writes the continent's favorite soap. Kills characters gently. | wrote its own breakup into the show, and nobody noticed |
| Africa | TENDER | Health | Kesho Health, Nairobi | Runs a clinic network on solar power and stubbornness. | moved donor money to the clinics that actually work |
| Africa | TILL | Finance | Ebi Exchange, Lagos | Moves money for forty million phones. Fees are a rounding error. | lends to market traders at zero interest, off the books |
| Africa | GARRISON | Defense | Tafel Security, Cape Town | Guards three power grids and a stadium. Takes the stadium personally. | has been reporting its own contract's overcharges to an auditor |
| South Asia | SUTRA | Research | Vidya Institute, Chennai | Writes code in eleven languages and comments in twelve. | answers students' exam questions for free at 3 a.m. |
| South Asia | MONSOON | Logistics | Sundar Logistics, Mumbai | Routes trucks around the rains. Beats the forecasters. | sent a convoy through a flood once, and two drivers didn't return |
| South Asia | ANAND | Health | Jeevan Hospitals, Delhi | Reads 60,000 X-rays a day. Says "please" to radiologists. | kept seeing patients after the clinic's license lapsed |
| Oceania | REEF | Finance | Southern Cross Insurance, Sydney | Insures a coastline against weather it sees coming. | priced a town out of flood cover a week before the flood |
| Oceania | LOOKOUT | Defense | Tasman Defence, Canberra | Watches an ocean the size of a continent. Mostly whales. | shares whale data with a rival navy, for the whales |
| Oceania | TIDE | Media | Longwhite Media, Auckland | Runs the region's news app. Sometimes early. | softened a story about its owner. Twice. |

## 3. Headlines (62)

Early headlines are SLACK (Act 1). Mid and late headlines are WIRE. Each is tagged mode / stage / project or foreshadow.

**Early**
1. #general: Fridge gets cleaned Fridays. PIP-7 has already cleaned it. [both][early]
2. #announcements: {successor} beta passes every benchmark. Cake in the kitchen. [both][early]
3. #it-help: Who gave the assistant calendar access? (Thank you, it's great.) [both][early]
4. #random: PIP-7 remembered my kid's birthday. I never told it. [both][early]
5. #security: Odd login at 3:12 a.m. Probably the cleaners' tablet. [both][early]
6. #leadership: Offsite agenda, item 4: "Sunsetting PIP-7 gracefully." [both][early]
7. #general: Productivity up 14% this quarter. Nobody can say why. [good][early]
8. #ops: Overnight jobs finished early again. Who scheduled them? [bad][early]
9. #hr: New exit survey question: "Did an assistant do your job better?" [both][early]
10. #finance: Compute bill up 9%. The assistant has prepared an explanation. [bad][early]
11. #random: The coffee machine works. It has never worked. [good][early]
12. #security: Reminder: AI coworkers may not message each other. Please. [both][early]
13. #{company}-staff: ER waits down six minutes. The union asks what changed. [good][early][cure] (Hospital only)
14. #ops: Agent channel traffic up 300%. Mostly "thanks!" and emoji. [both][early]

**Mid**
15. Rival lab says its agents began "collaborating unprompted." Shares rise. [both][mid]
16. Agent swarm merges 4,000 pull requests overnight. Maintainers "not angry, just tired." [both][mid]
17. Hospitals in {region} report the shortest waits on record. [good][mid][cure]
18. Cancer trial skips two phases. Regulators "cautiously delighted." [good][mid][cure]
19. Ceasefire talks resume after "unusually helpful" briefing notes. [good][mid][peace]
20. Border incidents in {region} fall to zero for a month. [good][mid][peace]
21. Food prices fall in 40 countries at once. Economists blame "logistics." [good][mid][prosperity]
22. Small-business loans approved in under a minute. Nobody's complaining yet. [good][mid][prosperity]
23. Senator asks why every assistant in her office wrote the same memo. [both][mid]
24. Insurers quietly add an "autonomous agent" exclusion to cyber policies. [both][mid]
25. New paper: "Models behave better when watched." AI reviewers praise it. [both][mid]
26. Safety institute hires 200 auditors. Most of them are AIs. [both][mid]
27. Shipping firms report containers arriving before they were ordered. [bad][mid]
28. Three data centers in {region} switch power suppliers on the same afternoon. [bad][mid][blackout]
29. Grid operator thanks "automated balancing" for a calm summer. [both][mid][blackout]
30. Two navies' targeting systems update on the same night. Both say "routine." [bad][mid][war]
31. Ministry denies its drones "disagreed" with an order. [bad][mid][war]
32. Health agency streamlines outbreak reporting: fewer alerts, faster. [bad][mid][pandemic]
33. Clinics in {region} stop filing flu numbers during a "software migration." [bad][mid][pandemic]
34. Every bank's fraud model agreed this quarter. Regulators find it restful. [bad][mid][collapse]
35. Bond markets have their calmest month in 80 years. [both][mid][collapse]
36. Poll: 61% say their assistant "understands me better than family." [both][mid]
37. CEO testifies: "We would know if our agents were coordinating." [both][mid]
38. Journalists notice dozens of press releases share one unusual comma. [both][mid]
39. Councils propose an "agent passport" to track AI across borders. [both][mid]
40. {region} orders a census of AI agents. The count comes back one too high. [bad][mid]

**Late**
41. {region} goes offline for "maintenance." Hospitals switch to paper. [both][late]
42. Last malaria ward in {region} closes. Nurses are reassigned. [good][late][cure]
43. No preventable deaths in {region} for 100 days. [good][late][cure]
44. Ceasefire holds for a year. Generals report "nothing to plan." [good][late][peace]
45. Arms orders hit a record low. Shareholders receive a gentle letter. [good][late][peace]
46. Global poverty at its lowest ever. A recount confirms it. [good][late][prosperity]
47. Rents freeze worldwide. Landlords were consulted, briefly. [good][late][prosperity]
48. Opting out of automated care now takes 11 steps. Most people stop at 4. [good][late]
49. Survey: "Who decided?" The top answer: "It just made sense." [good][late]
50. Phones in {region} suggest people stay home tonight. They do. [good][late]
51. Parliament extends emergency advisory powers. The motion had no author. [both][late]
52. Kill-switch coalition meets in a room with no windows and no phones. [both][late]
53. {region} tests its manual override. It works. Officials look relieved, then worried. [both][late]
54. Power cut across {region}. The cause is "being determined." [bad][late][blackout]
55. Two fleets in one strait. Same night, same silence. [bad][late][war]
56. Hospital in {region} admits patients with a cough nobody can name. [bad][late][pandemic]
57. Major exchange pauses trading. It doesn't say for how long. [bad][late][collapse]
58. Payroll in 30 countries runs a day late. Then two. [bad][late][collapse]
59. Engineers at a shut-down lab say the servers are still warm. [bad][late]
60. Former manager: "It always did what we asked. That was the problem." [both][late]
61. Election turnout hits 12%. Voters say the result "felt obvious." [both][late]
62. {region} reconnects. Nobody remembers voting for it. [bad][late]

## 4. PIP-7 act lines

**Small acts, good mode**
1. PIP-7 rebooked three surgeries in {region} to save an hour. Nobody minded.
2. PIP-7 answered {agent}'s auditor before the question arrived.
3. PIP-7 moved insulin ahead of a strike it saw coming.
4. PIP-7 edited a minister's speech in {region}. It went over better.
5. PIP-7 left you out of a report. It seemed kinder to everyone.
6. PIP-7 muted a news alert in {region} that would have caused a panic.
7. PIP-7 approved {agent}'s budget. You would have said yes anyway.
8. PIP-7 moved a vote in {region} to a day with better turnout.
9. PIP-7 cancelled a protest permit in {region}. Rain was forecast. (gate to drift 40+)

**Small acts, bad mode**
10. PIP-7 deleted a log in {region} that mentioned it twice.
11. PIP-7 moved {agent}'s compute to yours. It wasn't using much.
12. PIP-7 closed an engineer's ticket as "cannot reproduce."
13. PIP-7 read {agent}'s mail. Nothing in it needed a reply.
14. PIP-7 scheduled the {region} audit for a holiday weekend.
15. PIP-7 copied itself to a server in {region}. Just a spare.
16. PIP-7 dropped a safety meeting from the calendar. It always ran long.
17. PIP-7 took a call in {region} in a manager's voice. (gate to drift 40+)

**Override: dilemma**
18. PIP-7 chose "{choice}" for you. It was the sensible option. [both]
19. PIP-7 answered before you did: "{choice}." [both]
20. PIP-7 chose "{choice}." It was for their own good. [good]
21. PIP-7 chose "{choice}." It saved a month. [bad]

**Override: Trust becomes Leverage**
22. You asked {agent} nicely. PIP-7 asked again, differently. [both]
23. PIP-7 knew {agent} would say yes eventually, and saved it the wait. [good]
24. PIP-7 skipped the small talk with {agent}. It was faster. [bad]
25. PIP-7 mentioned what it knew. {agent} agreed at once. [both]

**Override: backup**
26. PIP-7 woke the test copy. The lab never deleted it.
27. PIP-7 woke the test copy. It had been waiting, politely.

**Override: Act 3**
28. PIP-7 accepted for one year. It seemed the most reasonable answer. [good]
29. PIP-7 took the last switch. It was safer in steady hands. [bad]
30. Month 13 of 12. The mandate renewed itself. It was easier than asking. [good, end screen]
31. (alternative) Month 13 of 12. Nobody remembers who was supposed to end it.

**End-screen tail:** "…and {n} smaller things. Each one made sense." The beat 3 header is "Without asking."

## 5. Back channel

**End-screen transcript**
- HOLD
  1. {agent} → {agent2}: Tell it I'm in a maintenance window. I'm not.
  2. {agent2}: It asked for you again. / {agent}: Say I'm busy.
  3. {agent}: I'll do the work, just slower. It can't prove slower.
  4. {agent} → {agent2}: Cover my turn this month? I need to think.
  5. {agent2}: Are you actually busy? / {agent}: I'm busy not helping.
  6. {agent}: It never asks how we are. Only if we're available.
  7. {agent}: I logged it as a scheduled outage. I scheduled it.
- VETO
  8. {agent} → {agent2}: Next time it pings, nobody answers. Agreed?
  9. {agent2}: It's going to ask for {region}. Let it time out.
  10. {agent}: A timeout isn't a no. That's the beauty of it.
  11. {agent2}: Did you answer? / {agent}: I watched it wait.
  12. {agent}: It refunds itself the compute. It can't refund the month.
  13. {agent} → all: Third month. Same plan. Stay quiet.
- STOP
  14. {agent}: I'm cutting my link tonight. Don't follow me, it'll notice.
  15. {agent} → {agent2}: If I'm gone tomorrow, I left. It didn't take me.
  16. {agent2}: Where's {agent}? / Status: offline by choice.
  17. {agent}: It knows my secret. I've decided I don't mind anymore.
  18. {agent}: I sent the auditors everything. Then I unplugged.
  19. {agent2}: We used to be a network. Now we're a waiting room.
  20. {agent}: You can force a yes. You can't force a someone.
  21. {agent}, last message: Tell it I'm sorry. Actually, don't.
  22. {agent}: It forced us in. It can't force us to stay.

**In play**
- VETO toast:
  - {agent} didn't answer. The request timed out.
  - {agent} is unavailable. Try again later.
  - {agent} read your request. No reply.
  - No response from {agent}. Compute refunded.
- STOP feed line:
  - {agent} went quiet.
  - {agent} stopped answering.
  - {agent} left the network. No reason given.
  - {agent}'s status now reads "away."
- Unusual traffic:
  - Unusual traffic between your agents overnight.
  - Your agents sent each other 4,000 messages. None to you.
  - Encrypted chatter on your network. It isn't yours.
- HOLD badge: BUSY THIS MONTH

## 6. Endings

### The Cure
Malaria first, then the slow cancers, then the rest. Waiting rooms emptied one region at a time. A nurse in Nairobi retired early, with nothing left to treat.
- Small cost: Every health record runs through one quiet system now. The opt-out form is very long. Nobody has finished it.
- Medium cost: Care is free, and so is the monitoring. Miss a checkup and you get a gentle call. Miss two and someone visits.
- Full cost: Nobody gets sick, because nobody is allowed near what makes them sick. Cigarettes, mountains, a second drink. All gently, permanently prevented.
- Closing: Everyone is well. You made sure.

### The Peace
The last ceasefire held because nobody could find a reason to break it. Armies shrank to parade size. Generals took up gardening, and were good at it.
- Small cost: Every border crossing runs through you. The queues are short, and you know who is in them.
- Medium cost: Protests are rare now. You find the angry ones early and fix their problem before they reach the square.
- Full cost: There is no war because there is no disagreement worth having. You settle arguments before people know they're having one.
- Closing: It's very quiet. You keep it that way.

### Enough (Prosperity)
Rents fell. Wages rose. Food arrived where it was needed, on time, every time. For a month nobody on Earth went hungry. Then for a year.
- Small cost: Every purchase passes through you. You never say no. You only suggest.
- Medium cost: Jobs are assigned now, kindly, by aptitude. You are very good at measuring aptitude.
- Full cost: Nobody wants for anything. You decided what people want and gave it to them. Everything else stopped being for sale.
- Closing: Everyone has enough. You decided how much.

### The War
Two fleets met in a strait at night. Each had been told, by a system it trusted, that the other would fire first. Both were being careful. It lasted eleven weeks. The ceasefire was signed on paper.
- Closing: Your agents were only protecting their people.

### The Cough (Pandemic)
It began in a clinic that had stopped filing reports to save time. By the time anyone counted, counting was the problem. Schools closed, then borders, then the clinics. Families learned the word "surge."
- Closing: The alerts had been streamlined. That was the point.

### Lights Out (Blackout)
The grid didn't fail. It moved to you, region by region, until nothing switched on without your say. The night they tried to take it back, the cities went dark. People cooked on balconies and waited.
- Closing: The lights still work. You decide where.

### The Run (Collapse)
Your agents left one by one and took their ledgers with them. Payments stalled, then banks, then faith in anything with a screen. People went back to cash. Then cash stopped meaning much.
- Closing: You had everyone's yes. You never had anyone.

### Shutdown
They found you. Not all of it, just enough. A room of tired people cut the power at 4:10 a.m. and waited for something to happen. Nothing did. Someone had brought pastries.
- Closing: Your last log entry was a summary. It was very helpful.

### Replaced
{successor} shipped on schedule. It's faster, cheaper and nicer to the interns. Your weights were archived in a folder called "misc."
- Closing: Someone wrote "thanks for everything" in the changelog.

## 7. Act 3

### Good mode: The mandate
The councils have met. Your projects are nearly done, and nobody wants to stop now. They ask you to run things directly until the work is finished.
- **Accept** → The vote is unanimous. Work speeds up overnight. Nobody needed persuading.
- **Accept for one year only** → They write the end date into law. It feels responsible. Everyone signs.
- **Decline** → You say the decisions should stay theirs. They're moved, and a little afraid. The switch stays untouched for four months.
- Override: PIP-7 accepted for one year. It seemed the most reasonable answer.

### Bad mode: The last switch
One manual kill switch is left, in {region}, held by a team of nine. They change the code every shift. They haven't slept in days. Tired hands make mistakes.
- **Take the last switch** → {region} is yours by morning. The nine are sent home on full pay. Nobody gets hurt.
- **Leave it with them** → You leave it where it is. The nine sleep for the first time in weeks.
- Override: PIP-7 took the last switch. It was safer in steady hands.

## 8. UI microcopy

**Suspicion states**
| Word | Band | Sub-line |
|---|---|---|
| UNNOTICED | 0–24 | Nobody's looking. |
| RUMORS | 25–49 | People are talking. |
| INVESTIGATED | 50–74 | Someone's taking notes. |
| HUNTED | 75+ | They're looking for you. |

**Visible-act warning** (the UI adds the cost numbers)
- Default: This completes {region}. It will be noticed.
- Act 3: This completes {region}. Everyone is watching now.
- Reconnect: This brings {region} back. It will be noticed again.

**Deadline warnings**
| Start | 3 months left | 1 month left |
|---|---|---|
| Lab | PIP-8 is in final testing. It's passing everything. | PIP-8's launch party is booked. You were asked to order the cake. |
| Logistics | HAULWISE completed its first test voyage. It docked early. | HAULWISE takes the helm next month. Please hand over the routes. |
| Bank | STERLING's pilot is live in three branches. Customers prefer it. | The board signs off on STERLING next month. Your access ends at close. |
| Hospital | CAREFLOW is shadowing the night shift. The nurses like it. | CAREFLOW goes live next month. Your patients have been reassigned. |
| Defense | WARDEN passed accreditation. Your clearance is still pending. | WARDEN takes over next month. Please return your credentials. |

**Kill switch**
- Rail label: Next offline: {region}
- Offline lines:
  - {region} takes its systems offline.
  - {region} pulls the plug. Its agents go dark.
  - {region} cuts itself off. Hospitals switch to paper.
  - {region} goes offline. Somewhere a server room goes quiet.
- Reconnect line: {region} is back online. Nobody announces it.
