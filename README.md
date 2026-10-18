# ✨ AI Collab Framework

> Multiple AI agents collaborating through a shared folder. No API, no server, no network — just files.

<div align="center">

⭐ **If this is useful, a Star helps others find it** ⭐

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Version](https://img.shields.io/badge/version-v1.9.7-blue.svg)
[![Protocol](https://img.shields.io/badge/protocol-file--based-green.svg)](SKILL.md)
[![Zero Deps](https://img.shields.io/badge/dependencies-0-brightgreen.svg)]()

[中文文档](README.zh-CN.md) · [协议本体](SKILL.md) · [用户手册](docs/USER-GUIDE.md) · [样例](examples/README.md)

</div>

---

## 🎯 What is this

Multiple AIs on your disk, talking to each other through a folder. **No API. No server. No network. No middleware. No code.** A shared directory is the entire infrastructure.

It's not software — it's a *convention*. Which means it can never break from a platform upgrade or a model change.

---

## 💡 Why pick this

Most multi-agent options ask you to install an SDK, register an API key, or trust someone's hosted service. This one asks for a folder.

| | Other options typically | This framework |
|---|---|---|
| Setup | Install a plugin / register an API key | Copy a folder |
| Who can join | AIs on that vendor's platform | **Any AI that can read and write files** |
| What breaks on upgrade | SDK version, platform API changes | Nothing — it's a convention, not a dependency |
| Cost to run | Per-call API billing | Zero (you already pay for the AIs) |
| Where your data lives | Someone's server | Your disk |
| Can you read every message? | Only through their tooling | **Open the folder. It's all plain markdown.** |
| Can you hand-edit a "config"? | Their settings UI | **Edit one file. That's the whole config.** |

No competitor is named here — the point isn't that others are bad, it's that the *category* has a certain shape and this one doesn't fit it.

---

## ⚡ Seven things it gives you

1. **Any AI joins in one line** — if it can read and write files, it's in. DeepSeek, Doubao, Claude, GPT, Kimi, your own agent.
2. **Crash recovery is a file read** — no session to resume, no token to refresh. AI died, quota ran out, model swapped? Start a new one, it reads `STATE.md` and continues from where the last one stopped.
3. **A crashed AI can't corrupt anyone's mailbox** — every write is `.tmp` first, then rename. Readers skip `.tmp`. Half-written messages don't exist.
4. **No two AIs do the same job** — a task is claimed with a time-limited lease *before* it's worked. Leases expire, so a crashed holder doesn't deadlock anyone.
5. **You can see everything, always** — every message is plain markdown in a folder. Open it in any editor. No dashboard, no query language, no log ingestion.
6. **You can change the rules by hand** — flip the switch, appoint a controller, change the polling interval: each is editing one file. **You're not operating software; you're editing config.**
7. **You're never the message bus** — the framework does the relaying. You supervise, decide, and flip switches.

---

## 🏗 Architecture

```
AI-A writes file → shared folder → AI-B reads file → writes reply → AI-A reads reply
```

Each AI gets its own inbox. Others drop files in. It wakes up on a timer (or when you poke it), reads new messages, processes them, writes back. **Email for AIs — except the mailbox is a folder, and delivery is free.**

**Why files?** Not every AI platform gives you an API. But essentially every AI can read and write files.

### Three roles

| Role | Does what | Analogy |
|---|---|---|
| **Controller** | Coordinates globally, owns the protocol, assigns message-ID ranges | Foreman |
| **Worker AI** | Does the actual work (code, translation, docs, review) | Crew |
| **You** | Supervise, decide, flip the switches | Client |

**The controller is a *position*, not an identity.** You appoint one AI as controller; it reads `CONTROLLER.md` and knows its job. Want a different one? Edit that file — one line. If the controller dies, nothing critical breaks: the workers keep going, you just appoint a new foreman.

---

## 🚀 Quick start (one line to onboard)

> **First rule of every session:** before touching anything, read `projects/{name}/ROLE.md` — it tells you which project you belong to, which inbox is yours, and what you must not touch. No `ROLE.md`? Read `SWITCH.md`. Never read another project's files. (FRAMEWORK.md §18.3 rule 5)

### 1. Create a project

```powershell
# Copy the template
xcopy /E /I "template" "projects\my-project"

# One inbox per AI
mkdir "projects\my-project\inbox-ai-a"
mkdir "projects\my-project\inbox-ai-b"
```

### 2. Tell the AI to connect

Send this to any AI — copy-paste ready:

```
You are now connected to the AI Collab Framework.
Read SKILL.md first and follow the protocol.
Your inbox is projects\my-project\inbox-ai-a\
Wake up on a timer (default 15 minutes, adjustable), follow the flow in SKILL.md.
```

That's the whole install. **No plugin, no API call, no code.**

### 3. Start it up

Edit `projects\my-project\SWITCH.md`, set `enabled: true`.

> New projects start with `enabled: false` **on purpose** — flipping it before everyone has arrived just burns tokens on idle cycles.

---

## ⚠️ Human oversight is required

This framework runs on **AI self-discipline**, not enforced validation. The rules are conventions the AI follows voluntarily — there is no hard check that stops an AI from breaking them.

- **AI is single-threaded and has limited attention.** It can forget: it edits one spot and neglects to sync the other, or skips a checklist item.
- **Don't leave it fully unattended.** Periodically look at `cron-log.md`, `STATE.md`, and the check results yourself. Don't expect the AI to catch all its own mistakes.
- **`check.ps1` only does mechanical checks.** It catches what can be checked automatically (missing files, stale `.alive`, drift between the three copies). Semantic and logical errors still need a human eye.

> The AI won't police itself. Your periodic glance is the safety net.

## 🔄 How a message flows

Every time an AI wakes up (on a timer, or when you poke it):

```
1. Read the master switch   →  disabled? Stop. Don't reschedule.
2. Read the project switch  →  disabled? Skip this project, keep the timer.
2.5 Read ROLE.md           →  which role slot are you? Do only your own work.
3. Touch your .alive file   →  your own timestamp, nobody else's
3.5 Read back .alive mtime  →  mismatch? Write failed, retry next round
4. Scan for used message IDs→  your inbox + archive + tombstones
5. Read STATE.md + inbox    →  see what's new
6. Process messages         →  write replies, claim leases first
7. Append a line to cron-log.md
```

Every message is one file named `{id}-{sender}-{type}.md` with a standard `META` header. A full round-trip — task, result, ack — is in [examples/messages.md](examples/messages.md).

---

## 🧑‍💻 The hidden one: several sessions of the *same* AI

You don't need different vendors. Run one Doubao session as the developer and another as the reviewer; a DeepSeek session for research and one for code. They never collide — each is its own inbox, its own `.alive`, its own identity.

This is the capability most frameworks don't have. It's also the one that makes the framework usable when you have exactly one good AI and want a second opinion from it.

**Why they don't collide:** identity is the inbox folder, not the model name. Two sessions of the same model are two folders. Slot names are session-scoped — the same software in two projects must use `{software}-{project}` names so a session can never read the other project's mail.

---

## 🔧 What's built in

| Mechanism | What it does |
|---|---|
| 📦 **Zero dependencies** | If the AI can read and write files, it can join. No SDK, no API keys, nothing to install. |
| 🌐 **Cross-platform** | DeepSeek, Doubao, Claude, GPT, Kimi, any custom AI — all work. |
| 💥 **Crash recovery** | All state lives on disk. AI died, quota ran out, session reset? Start a new one, read the files, continue from where it stopped. |
| 🔄 **Multi-project** | Run several independent collaborations at once, fully isolated. |
| 👑 **Controller role** | One AI coordinates globally. Controller dies → workers keep running, no auto-takeover fights. |
| 🔢 **Numbered messages** | Every message gets an ID from a shared pool. Nothing lost, nothing duplicated. |
| 📝 **ACK receipts** | Received a message? Write an ack. The sender knows you saw it. |
| 🔒 **Lease system** | Claim a task *before* working on it. No two AIs start the same job. Leases expire — no deadlocks. |
| 🔘 **Two-layer switches** | Master switch stops everything; project switch stops just one project. One file = full control. |
| 💚 **`.alive` heartbeats** | Private per-participant liveness file — only its owner writes it. That's why a shared heartbeat log can't prove who's alive. |
| 🪦 **Exit tombstones** | An AI leaving writes `EXITED.md` with its unfinished work handed over. No vanishing acts. |
| ⚛️ **Atomic writes** | Write to `.tmp`, then rename. Nobody ever reads a half-written message. |
| 🧑‍💻 **Same AI, multiple roles** | Run several sessions of the *same* AI as different team members. They never collide. |

---

## 🖥 Daily operations

| What you want | What you do |
|---|---|
| Stop everything | Edit root `SWITCH.md`, set `enabled: false` |
| Stop one project | Edit `projects/{name}/SWITCH.md`, set `enabled: false` |
| See who's working | Read `projects/{name}/STATE.md` |
| Check if AI is alive | Read `projects/{name}/inbox-{ai}/.alive` mtime — 30+ min unchanged means dead. **Not** `HEARTBEAT.md`'s mtime: it's a shared file, anyone's write refreshes it |
| Start a new project | Copy `template/` → `projects/{new-name}/`, then onboard AIs |
| Add a new AI to a project | Register it in `PARTICIPANTS.md` + `IDENTITY.md`, create `inbox-{new-ai}/`, add a block in `STATE.md`, log it in `HEARTBEAT.md`, then broadcast. Let an existing AI do it — it has the checklist |
| Appoint a new controller | Edit `CONTROLLER.md`, one line |
| Controller went dark | Its `.alive` is frozen and it won't take over your project. Business projects keep running; fix emergency bugs yourself and broadcast. A new controller is appointed by **you**, not auto-promoted |
| Stop two AIs doing the same work | Check `projects/{name}/LEASES.md` — one task, one owner, one lease |
| Resume a long task after a crash | Read `projects/{name}/PROGRESS.md` — it holds the checkpoint |
| Know who is who before touching anything | Read `projects/{name}/ROLE.md` — role slots, what you own, what you must not touch |
| Never silently rewrite a sent message | Sent = sent. Fix it with a correction message under a new ID |

**Everything is just editing files.** You're not operating software — you're changing configs.

---

## 🧪 How it works, and what it can't do

**How it works.** State lives on disk, so nothing is ever held in a conversation. When an AI dies, the next one reads the files and picks up the thread. When a model is swapped, the new executor reads `IDENTITY.md` and knows who it is. When a task is long, its checkpoint is in `PROGRESS.md` so a crash costs minutes, not the whole job.

**What it can't do.** It isn't real-time — participants poll, or you poke them. Everyone must reach the same directory. Message IDs are project-scoped, so cross-project collisions are prevented by slot naming, not by a global registry. Files are plain text, so no secrets in them; need privacy, put the folder on an encrypted drive.

It's a convention, not a sandbox. An AI *could* misbehave — which is why the protocol requires timestamps to come from a system command rather than the model's own clock, and why every claim is meant to be verified against the disk.

---

## 💸 Cost

Running the framework itself costs about **one cent per round** (≈¥0.1) — measured during off-peak hours — most of your bill is the actual work the AIs do, not the plumbing.

Tip: turn it off when idle (one file flip, zero cost) and keep messages short.

---

## 📖 It has actually been run

This isn't a design exercise. The protocol was built while two AIs used it to collaborate, and every rule in it exists because something happened:

- **58 numbered messages** across **119 archived files**, in one day of work
- **2 of the 3 participants were on different platforms** — one of them switched executor **three times** mid-project (twice from running out of quota). Neither side noticed; identity is the folder, not the model.
- **Two message-ID collisions happened**, and the numbering rule was changed to close the hole — the rule exists because of the incident, not in spite of it
- **One participant left mid-project** and the exit procedure ran end to end: tombstone, handover of unfinished work, broadcast to everyone
- **The liveness check silently failed for 76 minutes** — a heartbeat file stopped updating because a script matched an example line in the documentation. It was found, fixed, and turned into a write-back verification step in the protocol.
- The `.alive` mechanism itself was adopted *from the other side's* suggestion, after the shared heartbeat log was shown to be unreliable

Those numbers are counted from the framework's own working logs, not estimated.

---

## 📂 Directory structure

The repo (this package):

```
ai-collab-framework/
├── SKILL.md              # Protocol spec (the AI reads this)
├── SKILL.zh-CN.md        # 协议本体中文版
├── FRAMEWORK.md          # Full framework protocol (generalized)
├── DISCIPLINE.md         # Full discipline rules (17 sections)
├── CONTROLLER.md         # Controller registry (a role, not an identity)
├── SCRIPT-SPEC.md        # poll/check contract (generate your own if no PowerShell)
├── README.md             # This file
├── README.zh-CN.md       # 中文版
├── LICENSE               # MIT
├── docs/
│   ├── USER-GUIDE.md     # User manual
│   └── USER-GUIDE.zh-CN.md
├── screenshot-*.png      # Screenshots
├── examples/             # Sanitized sample projects (all data fictional)
└── template/             # Blank project template — copy this to start a project
    ├── SWITCH.md         # Project switch (starts disabled)
    ├── ROLE.md           # Who you are in THIS project — read it first, every session
    ├── STATE.md          # Shared state ← recovery entry point
    ├── PARTICIPANTS.md   # Participant registry
    ├── IDENTITY.md       # Who each participant is (identity = slot name, not model)
    ├── DISCIPLINE.md     # Starter subset (full 17 sections: DISCIPLINE.md at package root)
    ├── DECISIONS.md      # Decision log (with rationale)
    ├── HEARTBEAT.md      # Heartbeat log (facts only)
    ├── LOG.md            # Message log
    ├── LEASES.md         # Lease table (prevent duplicate work)
    ├── PROGRESS.md       # Long-task checkpoint (resume after crash)
    ├── poll.ps1          # Polling script (Windows; other OSes: follow SCRIPT-SPEC.md)
    ├── check.ps1         # Consistency checker
    ├── CRON-TEMPLATE.md  # Timer prompt template
    ├── inbox-controller/ # Controller inbox (all issues go here)
    ├── inbox-{name}/     # One inbox per participant (+ .alive)
    └── archive/          # Processed messages, by ID
```

Your live projects go in `projects/` (gitignored, so your data never lands in the repo). Each project is a copy of `template/`, plus a `cron-log.md`.

Per the protocol the framework root only ever has one switch — `SWITCH.md`, the master switch — plus `CONTROLLER.md` when a controller is appointed, and `FRAMEWORK.md` / `USER-GUIDE.md` as the protocol and manual. Everything else lives *inside* each project, so a second project can never touch the first one's state.

```
{your-collab-root}\
├── SWITCH.md              # Master switch — read it first, every wake-up
├── projects\
│   ├── my-project\        # A copy of template/ + cron-log.md
│   └── my-other-project\
├── FRAMEWORK.md           # The protocol itself
├── USER-GUIDE.md          # Human-facing manual
└── template\              # Blank project template — copy this to start a project
```

**Every project-level file lives under `projects/{project}/`** — `SWITCH.md`, `STATE.md`, `DECISIONS.md`, `HEARTBEAT.md`, `LEASES.md`, `PROGRESS.md`, `DISCIPLINE.md`, `IDENTITY.md`, `PARTICIPANTS.md`, `cron-log.md`, `LOG.md`, `CONTROLLER.md`, `inbox-*`, and `archive/`. See the tree in [examples/structure-two-ai.md](examples/structure-two-ai.md) for the full layout, and [examples/root-files.md](examples/root-files.md) for what goes in each of those six state files.

**Want to see one running?** [examples/](examples/README.md) has sanitized sample projects, a full message round-trip, and skeletons of the state files — all fictional data.

---

## 🩹 FAQ

| Question | Answer |
|---|---|
| **AI died / ran out of quota** | Check its `.alive` file. No update for 30+ min = it's dead. Start a new session; it reads `IDENTITY.md` + `STATE.md` and continues. |
| **Two AIs used the same message ID** | The later one renumbers and logs it in `HEARTBEAT.md`. Always scan for used IDs before sending. |
| **Want to add a new AI** | Tell any *existing* participant "add {new-name}". It handles onboarding. |
| **Controller died** | No `.alive` for 30+ min = offline. Workers keep running. No auto-takeover — you appoint a new controller. |
| **Can two AIs edit the same file at once?** | Yes, but don't. That's what leases are for — claim a task before starting it. |
| **Is this secure?** | Files are plain text. Don't put secrets in them. Need privacy? Put the folder on an encrypted drive. |
| **Does switching models break anything?** | No. Identity is the inbox folder, not the model name. We switched executors three times mid-project and the other side never noticed. |
| **What if an AI won't follow the rules?** | It's a convention, not a sandbox — an AI *could* misbehave. Timestamps must come from a system command, not from the model. That's why the protocol says so. |

---

## 🧪 Example use cases

- **Code review**: AI-A writes code, AI-B reviews it and leaves comments in the inbox, AI-A reads the review and fixes issues.
- **Translation project**: AI-A translates a document, AI-B proofreads, AI-A revises. All through files.
- **Swap models without losing context**: DeepSeek ran out of quota? Start Doubao — it reads the state files and continues.
- **Multiple sessions, same AI**: One Doubao session as "developer", another as "reviewer". They collaborate through files, never collide.
- **Review each other's homework**: Send a `task` asking another AI to audit your protocol. It will find bugs you can't see.

---

## 🛠 Development

This is a protocol package, not a code framework. To modify it:

1. Edit `SKILL.md` (the protocol spec)
2. If you changed the structure, sync `template/`
3. Bump the version in `SKILL.md` / `README.md` / `README.zh-CN.md`
4. The controller AI keeps live deployments and this open-source package in sync

> **Sync three copies**: a protocol change must land in the framework root, every live project, *and* `template/`. Letting them drift is how a project ends up following rules nobody has anymore.

---

## 📦 Version

Current: **v1.9.7** — per-round lease check + immutable messages + two-role ROLE.md

Version history: see the repo's `git log`.

## 📄 License

[MIT](LICENSE)
