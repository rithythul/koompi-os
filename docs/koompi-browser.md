# KOOMPI Browser — Technical Blueprint

Status: brainstorm-grade architecture, v0.1 · Generated from `koompi-browser-prompt.md`
Frame: the browser is the partner's window to the web — a citizen of the thinks-stack,
not a second brain. Every decision below is checked against the frame test: more capable
without taking data · privacy posture in pixels · runs on a UHD 620 / 4–8 GB floor ·
still coherent in year 30.

---

## 1 · OS-Native Intelligence: One Brain, Not Two

### 1.1 Runtime integration, not embedding

**Decision: the browser ships no LLM.** Every generative task goes to `koompi-assistantd`
(L2) over the local Unix socket. The measured case for an in-process 1.5–3B SLM
evaporates on inspection: socket round-trip is sub-millisecond, token generation
dominates end-to-end latency by 3–4 orders of magnitude, and a second model stack means
a second RAM resident (fatal on the 4 GB floor), a second update channel, and a second
thing the Model Manager can't see. "One brain" is taken literally.

What *does* run in-process are **tiny ONNX classifiers** (~5–20 MB, CPU, <10 ms) for
tasks where IPC-per-keystroke would be absurd:

| classifier | job | budget |
|---|---|---|
| `intent-router` | ask-bar input → URL / search / question / command | <10 ms/keystroke |
| `content-class` | page category (banking, health, docs, shop) → consent defaults | <30 ms/load |
| `instr-taint` | flags imperative-toward-agent spans in page text (§3.4) | <50 ms/page |

These register with the OS Model Manager as a model tier — they update, roll back, and
report through the same machinery as the big models, not a private pipeline.

**Process model.** QML/Quickshell chrome (shell design system, hot-reload) · QtWebEngine
renderer processes (Chromium sandbox intact) · `koompi-webd`, a Zig daemon owning canvas
state, the capture pipeline, capsules, and the CLI. Rust crates (shared with the OS) for
the egress hooks, the semantic-selector engine, and the credential-broker client.

### 1.2 Hybrid routing under ADR-0001

The browser never routes to a cloud model. It hands tasks to assistantd with metadata
(task class, content size, canvas id); assistantd's router decides local tier vs
KOOMPI.Cloud. If the answer is "cloud," the user sees the standard **amber consent
moment** naming what leaves (the cleaned article AST, never the raw page or cookies),
and the Egress Ledger gets a receipt. Below the floor, assistantd degrades local and
says so. Silent fallback is a contract violation, not a tuning knob.

Latency budgets the UI is designed around (UHD 620 floor):

| task | path | target |
|---|---|---|
| ask-bar intent | in-process classifier | <10 ms |
| reader re-render (cached IR) | webd cache | <50 ms |
| reader re-render (cold) | assistantd local 3B | 2–6 s, streamed |
| research agent step | assistantd local 8B | 10–40 s, background |
| anything cloud | egress + consent | never silent |

### 1.3 Browsing memory, not browser history

There is **no browser history database**. Navigation produces capture events that flow
through one pipeline into the OS stores:

```
navigation → readability extract (local, Rust)
          → consent gate (Policy Engine: per-site scope)
          → contextd ingest (chunk + embed → the one index)
          → agent-memd episodic event (visit record → the one memory)
```

- **Per-site scopes** (Policy Engine, clipboard-style): `metadata-only` (URL + title —
  the default), `full-content` (opt-in per site), `never` (auto-suggested when
  `content-class` says banking/health; one tap to confirm). The scope chip lives in the
  address bar — posture in pixels.
- **Privacy states per entry** exactly as Files (§45): INDEXED · SHARED · LEAKED-ONCE.
- **Incognito is a no-write mode** enforced at the pipeline entry *and* with an
  ephemeral renderer profile — not a UI flag over a warm cache.
- **Forgetting**: browsing memories are ordinary memories — Suppress / Seal / Destroy
  via Ceremonial Forgetting, blast-radius shown (which notes cite the page).

Result: "the article about land-title registration I read before the Bangkok trip" is a
Launcher query, not a history-scroll — same One Ask session, same index as everything
else you own.

## 2 · Radical Interface: Workspace over Tabs

### 2.1 The Zero-Tab paradigm: Builder Canvases

A **Canvas** is a persistent task container: `{web pages, local files, terminal panes,
agent threads, notes}` with one identity on koompi-busd. Canvases map onto Hyprland
workspaces — the AI's workspace labels and smart placement apply to web work, and the
§07 Overview shows canvases as first-class tiles.

Honesty clause: pages inside a canvas are still pages — "zero-tab" abolishes the
*global undifferentiated tab soup*, not the concept of multiple documents. Within a
canvas: an MRU page stack, semantic grouping (the same clustering contextd already
does), and aggressive hibernation (a frozen page is an IR snapshot + URL, ~100 KB, not
a renderer process — this is what makes 20 "open" pages viable on 4 GB).

Canvas state serializes into the §48 **Context Capsule** format: handoff a research
canvas to the phone, choose Continue or Fork on arrival. Per-canvas **cookie jars**
(container model): your "banking" canvas and your "research" canvas are different
people as far as the web can tell; a canvas can be bound to a network posture
("travel canvas only exists over VPN" — §40 lattice).

### 2.2 Generative re-rendering with provenance

The mechanism, precisely:

1. **Snapshot**: webd serializes the page as a cleaned article AST — Readability-class
   extraction in Rust over the DOM + accessibility tree. Raw HTML never reaches a model.
2. **IR generation**: assistantd transforms the AST into a layout IR — markdown blocks,
   table specs, callouts — where **every block carries `sourceNodeRef`** back to DOM
   node IDs, and synthesized content (a comparison table cell) carries the refs of all
   contributing nodes.
3. **Render**: QML reader renders the IR in the shell design system. Hover any block →
   the original DOM region highlights. <kbd>O</kbd> toggles the untouched original.
4. **Marking**: the view carries the §77 provenance chip — **AI-assisted re-render** —
   and table cells distinguish *recorded* (extracted) from *inferred* (synthesized).
5. **Cache**: IR cached by content hash → re-renders are instant and work offline.

The browser never silently rewrites the web. The visible mark, the one-keystroke
original, and the per-cell citations are what make the rewriting trustworthy.

### 2.3 Ambient async with honest motion

Agent threads are assistantd sessions bound to a canvas. The canvas chip carries the
indigo **breathing** dot while cognition runs; directional bars appear only for
transfer (downloads, capsule sync). The thread panel is a step ledger (✓ done · ●
breathing · ○ queued); outputs land as **drafts in the canvas** — staged, per the
Proactive OS rules: prepare freely, propose, never send unasked. <kbd>Esc</kbd> pauses
any thread. Every thread runs under a policy budget (pages fetched, tokens, minutes);
exhausting a budget pauses and asks rather than silently continuing.

### 2.4 Khmer-first web

ICU dictionary break-iterator for selection, double-click word-select, and
find-in-page on spaceless Khmer; Khmer/Arabic numeral folding in find; km-collation in
canvas search; register-aware local translate (formal/informal/royal) as a side pane
that never leaves the device; Khmer TTS read-aloud via the OS accessibility stack.
First-class from minute zero, not a translation layer bolted on.

## 3 · The Action Layer: Agency with a Leash

### 3.1 Semantic web automation

Agents act on the **accessibility tree + semantic DOM**, never CSS selectors. A target
is a *semantic selector*: `(role, accessible-name≈, landmark path, local text-context
embedding)`. Plans compile to a step IR; **every step re-grounds at execution** —
candidates are scored against the selector, and below threshold the plan pauses and
asks instead of guessing. This is what survives redesigns: the "Download" link keeps
its role and name when its div soup changes.

- **Dry-run is the default first run**: targets highlight as an overlay; nothing acts
  until approved.
- **Replay journal**: each step records `(selector, resolved-node fingerprint, action,
  result hash)` — deterministic replays, auditable failures, and the §57-style delta
  journal for undo.
- Automations are **busd capabilities** — `web.extract`, `web.fill`, `web.download`,
  `web.submit` — callable by the assistant or any consented app.

### 3.2 Consent that scales

Action classes bind to the one Policy Engine (precedence `floor > constitution > app >
session`):

| class | examples | default |
|---|---|---|
| read | fetch, extract | allowed within site scope |
| interact | fill forms, click, paginate | session policy via Tool Approval |
| commit | submit, post, purchase | **always asks** — constitution may *narrow*, never waive money |
| credential | login | broker only, never scriptable |

Every commit-class action produces an undo receipt and an Egress Ledger entry against
its rule ID.

### 3.3 Containment tiers

| trust | engine | use |
|---|---|---|
| normal browsing | QtWebEngine renderer sandbox | default |
| autonomous scraping / unknown sites | headless engine service in **bwrap + netns** | agent threads |
| hostile / unvetted | **Detonation Chamber** microVM; only screenshots + AX-tree exit | "open this sketchy link" |

**Logins**: the host-side credential Broker (ADR-0011/0012) performs auth in trusted
chrome — device-code or loopback relay — and hands the page context a short-TTL
session, scoped to the canvas's cookie jar. Passwords never exist inside a page or an
agent's reach.

### 3.4 Prompt injection, concretely

1. **Channel separation**: page content reaches agents as typed, quoted *data blocks*;
   the instruction channel is OS-only. No concatenated soup.
2. **Taint pass**: `instr-taint` flags imperative-toward-agent spans ("ignore previous
   instructions…") before content reaches assistantd; flagged spans are stripped from
   the data block and quarantined.
3. **Violation surface**: a red banner — *"This page attempted to instruct your
   agent"* — plus a ledger entry. Teachable, not just blocked.
4. **Capability ceiling**: during autonomous runs, page-derived plans cannot trigger
   commit-class or credential-class actions, period. A human re-confirms at the
   boundary even if a standing policy would otherwise allow it.
5. Accept the honest limit: injection is not solved in the adversarial limit (§5,
   open problem 2). The ceilings bound the blast radius; they do not pretend immunity.

### 3.5 Web3-native: the brokered wallet

**No injected wallet, ever.** Pages get a provider shim — EIP-1193 for EVM dApps, a
Substrate-compatible signer interface for Selendra-class chains — that proxies every
request to `koompi-vault` via the `web3.*` busd capabilities. Keys never exist in a
page context; every signature is the Vault **signing ceremony** in trusted chrome the
page cannot draw over: local transaction simulation rendered as a sentence ("send 25
SEL to vathna.sel · approvals granted: none"), unlimited-allowance and
`setApprovalForAll` drainer patterns refused by default with plain-language warnings,
and spend bound to the Constitution's commit-class limits.

**Multichain by broker, not by extension zoo**: Selendra is the home chain; EVM chains,
Bitcoin, and other Substrate networks ride the same Vault custody and the same ceremony.
Name resolution (`.sel`, ENS) is cached locally and resolves OS-wide. **Per-canvas
wallet identity**: each canvas exposes a derived account, so dApps in different
canvases see different addresses unless you link them deliberately — the cookie-jar
container model extended to value. Chain RPC is ordinary egress: destination, bytes,
rule ID in the Ledger.

## 4 · Hardware-Efficient & Builder-Centric Innovations

1. **Pipe the web** — `koompi web page --md | grep …`: the current canvas page (or any
   URL fetched through the same consent stack) as markdown/JSON/AX-tree on stdout.
   The web becomes a shell citizen; scripts inherit the user's scopes and ledger.
2. **pacman-aware documentation** — the `content-class` + heuristics detect install
   instructions; a card offers the real signed package (`pacman -S nodejs`, repo
   signature shown) and **diffs `curl | bash` scripts against the packaged version**.
   Kills the single most dangerous habit in Linux onboarding.
3. **Classroom capsules** — `koompi web capsule <site|list>` builds an offline archive
   (WARC + IR cache) served over mDNS/LAN mesh. A teacher publishes the week's set; a
   lab with no internet still has the web that matters. Metered-network aware end to end.
4. **Khmer-first everything** (§2.4) — segmentation, find, collation, translate, TTS:
   the features no Valley browser will ever prioritize, default here.
5. **P2P/IPFS as first-class protocols** — `ipfs://` via a local gateway (optional
   package, off by default per egress posture); opt-in Selendra provenance chip
   verifying content hashes against anchored roots (ADR-0009 discipline: roots only).
6. **Energy-honest tiers** — IR caching and re-index batching defer to AC/solar surplus
   (sleep-tier alignment); canvas hibernation budgets tuned per §56's GPU tiers; on the
   UHD 620 floor the browser freezes aggressively and *says what it froze* instead of
   swapping silently.
7. **Per-canvas identity** — cookie-jar containers bound to network posture: the
   browser inherits the §40 lattice instead of inventing its own VPN logic.

## 5 · Implementation Stack & v1 Scope

### 5.1 Engine and layers (ADR-0004 discipline)

**Engine: QtWebEngine (Chromium) for v1.** Reasoning: a from-scratch or forked engine
is a 30M-LOC security treadmill no small team survives; QtWebEngine delivers Chromium's
sandbox and codec maturity, is maintained upstream by the Qt project, ships without
Google service keys, and embeds natively in the QML chrome. **The hedge is an engine
isolation boundary**: chrome, webd, capture, and automation speak to the engine only
through a thin trait (`navigate, snapshot-AST, AX-tree, exec-step, jar-control`).
Servo (Rust, Linux Foundation) is tracked as the 2030s candidate; the boundary is what
makes a 50-year horizon compatible with a 2026 Chromium dependency.

| layer | language | components |
|---|---|---|
| chrome / reader | QML/Quickshell | canvas rail, ask-bar, reader, thread panel — hot-reload, shell tokens |
| session daemon | Zig | `koompi-webd`: canvases, capture pipeline, capsules, CLI |
| security surfaces | Rust | egress hooks, broker client, semantic-selector engine, taint runtime |
| AI tools | Python (in assistantd) | research / summarize / compare — exposed as busd capabilities |

**Privacy by topology**: renderers reach the network only through the OS egress gate
(per-canvas cgroup rules). The AI tool layer has no network socket at all — its only
road out is `koompi-egress`. Ledger pragmatics: per-site **aggregated receipts**
(bytes, destinations, rule IDs) with drill-down sampling, full per-request logging in
paranoid mode — the ledger stays readable on a chatty web.

### 5.2 v1 "Naga" vs 1.x

**v1 (Naga)**: QtWebEngine in QML chrome · named canvases with per-canvas
jars (no capsule sync yet) · One Ask address bar · reader re-render with provenance +
<kbd>O</kbd> · contextd ingestion with per-site scopes + incognito no-write · three
automations through Tool Approval (download+verify, form-fill, page→Notes) ·
pacman card · Khmer find/translate · read-only Web3 (name resolution, balances, provenance verify).

**1.x**: agent threads + budgets · capsule handoff · headless bwrap scraping tier +
Detonation Chamber · `koompi web` CLI · classroom capsules · IPFS/provenance ·
energy tiers · the dApp provider + signing ceremony + agent commerce · Servo experiments behind the boundary.

### 5.3 The three hardest open problems — stated honestly

1. **The Chromium treadmill vs the 50-year horizon.** Weekly upstream security churn is
   a structural dependency on Google's roadmap. *Bet*: the engine isolation boundary +
   tracked Servo optionality + funding/upstreaming Qt WebEngine work. Accept that for
   the next decade, engine sovereignty is partial — and say so in the Continuity
   Charter rather than pretend otherwise.
2. **Prompt injection in the adversarial limit.** Channel separation and taint passes
   raise the bar; they do not close the theory gap. *Bet*: capability ceilings + human
   gates on commit/credential classes — deliberately trading agent autonomy for bounded
   blast radius, and revisiting as instruction-data separation research matures.
3. **Ledger legibility vs web chattiness.** A single page can touch 80 hosts; logging
   everything drowns the user, aggregating risks hiding the one flow that matters.
   *Bet*: per-site aggregated receipts with anomaly surfacing (new destination, new
   category → full detail), paranoid mode for full logging — and honest acknowledgment
   that legibility is a UX research problem, not a solved checkbox.
