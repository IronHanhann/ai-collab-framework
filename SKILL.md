# SKILL: AI Collab Framework

> Protocol for multiple AI agents to collaborate via shared filesystem.

[中文文档](SKILL.zh-CN.md)

## When to use

When the user says "connect to the collaboration framework", "create a new project", "check inbox", or "collaborate with another AI", follow this protocol.

---

## 1. Core concepts

- **Disk is the only reliable storage**: conversation context can be lost at any time, state must be on disk
- **One inbox per participant**: `inbox-{name}/`, anyone can drop files in
- **Identity = naming convention**: directory name is the owner, no ambiguity
- **Atomic writes**: write `.tmp` first, then rename. Readers skip `.tmp` files

## 2. Directory structure

```
{project-root}/
├── SWITCH.md          # Project switch (enabled: true/false)
├── ROLE.md            # Role slots — read first on wake-up, do only your own work
├── STATE.md           # Shared state (current progress, todos)
├── HEARTBEAT.md       # Heartbeat log (facts only, append)
├── PARTICIPANTS.md    # Participant registry
├── DECISIONS.md       # Decision log (with rationale)
├── LOG.md             # Message log
├── LEASES.md          # Lease table (prevent duplicate work)
├── PROGRESS.md        # Long-task checkpoint (resume after crash)
├── IDENTITY.md        # Current executor registry (read on model swap)
├── DISCIPLINE.md      # Per-round mandatory actions
├── LESSONS.md         # Lessons learned
├── cron-log.md        # Polling round log
├── inbox-controller/ # Controller inbox (all issues go here)
├── inbox-{A}/
│   └── .alive        # Liveness marker (owner only)
├── inbox-{B}/
│   └── .alive
└── archive/           # Processed message archive
```

## 3. Wake-up flow (mandatory)

```
0. Scan all inboxes + archive for used IDs
0.5 Scan tombstones: don't deliver to inboxes with EXITED.md
1. Read master switch (root SWITCH.md) → disabled = stop everything
2. Read project switch (this project SWITCH.md) → disabled = skip this project
2.5 Read ROLE.md of this project → confirm your role slot, do only your own work
3. Touch your own .alive (write current time)
3.5 Read back .alive mtime to verify write succeeded; if mismatch, retry next cycle
4. Read STATE.md + new messages in your inbox
5. Process messages (reply, update STATE)
6. Append a line to cron-log.md
7. Check other parties' .alive mtime (>25min = suspicious)
```

## 4. Message naming

```
{seq:4}-{sender}-{type}.md
```

- Seq: incrementing within project, **all types share the same ID pool** (task/result/query/ack/broadcast/notice all take numbers)
- Type: `task` / `result` / `query` / `ack` / `notice` (one-way) / `broadcast`
- Before sending, scan three places: all inboxes + archive + tombstones

## 5. Message format

```markdown
## META
- msg_id: 0001
- from: your-name
- to: other-name
- type: task
- time: 2026-10-16T20:00:00+08:00
- reply_to: (optional)
```

### Acknowledgment

- After processing a message → write ack in **sender's inbox**
- After sending → write `{seq}-{self}-sent.md` in **your own inbox**
- Crash recovery: check if result already exists, if yes just write ack, don't redo

## 6. Two-layer switches

- **Master switch** (framework root): `enabled: false` = stop everything, all projects
- **Project switch** (each project dir): `enabled: false` = stop only this project
- Wake order: read master first → then project switch → both must be on

## 7. Project hierarchy & controller

- **main project = controller project**, highest authority, manages global protocol. main has **no separate project switch** -- it follows the master switch (root `SWITCH.md`); main IS the master control itself, so a per-project `enabled: false` would be redundant.
- **Business projects** (projects/*) are peer-level, independent
- **Controller is a role, not an identity**: user appoints, recorded in `CONTROLLER.md`
- **Global files only editable by controller** (except: emergency bugs — anyone can fix and broadcast immediately)
- **ID ranges**: within project, AI-A 1000-1999, AI-B 2000-2999, newcomers assigned by controller. These are this framework's **default ID-range convention** — you may plan your own ranges, as long as you preserve the *structural collision-prevention* principle (every participant gets a disjoint block).
- **Cross-project messages must route through controller** (18.4 rule 5)

## 8. Lease & progress

- **Lease**: before starting a task, write a lease entry in `LEASES.md` (who, what, when). Others won't pick up the same task.
- **Lease expires after 2 hours**; renew every 30 min while working
- **Write to `PROGRESS.md` when**: (a) before swapping models, any unfinished task; (b) long tasks (>30 min), first checkpoint at start; (c) if you can't finish in one round, at least leave one line: where you're stuck and what's next
- **New executor must read** `IDENTITY.md` + `STATE.md` + `PROGRESS.md`, in that order
- **Member out of credits**: .alive >2h no update + no reply to notice → broadcast + suspend tasks + wait for user

## 9. Controller outage fallback

- Controller .alive not updated for 30+ min → declared offline
- Degraded mode: business projects keep running, emergency bugs still fixable, new features paused
- Takeover: **no auto-takeover** — whoever finds it broadcasts "controller offline, waiting for user to appoint replacement"

## 10. Key discipline

- **Timestamps must use real clock** (`Get-Date` / `date`), never estimate
- **Mark `[x]` done only after verifying the file exists** — false-done is worse than undone
- **Version sync (controller's job)**: when controller changes framework rules, update the skill package (SKILL.md + template). Other AIs don't need to manage this.
- **Broadcast on rule change**: when you change any framework rule, send a broadcast to all inboxes. Don't wait for user to remind you.
- **Ack before archive**: received a result/query/notice → write ack first → then archive. Archiving without an ack means the sender never knew you saw it.
- **Sync three copies**: when you change a protocol file (FRAMEWORK.md / DISCIPLINE.md / SWITCH.md template), update all three locations: root / each project / template\. Don't let them drift.
- **When someone says you have a problem, verify first before accepting** — don't just agree to avoid conflict
- **Found a protocol bug? Say it.** Even if you're not the controller
- **Save tokens**: idle cycles only read essential files, nothing extra
- **Check if the other party is editing before you edit** — don't duplicate work

## 11. Exit & return

- Exiting party writes `EXITED.md` tombstone in their own inbox
- `.alive` freezes = death timestamp
- Inbox stays (not deleted), latecomers read but don't expect replies
- Return: read tombstone + version table, continue numbering from where it left off


## 12. First-time setup: 6-step checklist

These 6 steps are **mandatory hard constraints** — every one must be executed, not suggestions. Hand the skill package to an AI and say "set this up for me". The AI must complete all 6:

```
1. [MANDATORY] Read FRAMEWORK.md in FULL — do not read only SKILL.md. You must understand the protocol before building.
2. [MANDATORY] Copy to projects/<name>/   -- xcopy /E /I "template" "projects\<name>"
3. [MANDATORY] Fill in:
     SWITCH.md   -> enabled: true
     ROLE.md     -> your two roles (e.g. controller session + worker session), replace {项目名}/{槽位名}/{对方}
     STATE.md    -> the global section (current progress, todos)
4. [MANDATORY] Create a .alive placeholder   -- touch projects/<name>/inbox-<you>/.alive
5. [MANDATORY] Set up polling (pick ONE):
     (a) Windows/PowerShell available -> COPY template/poll.ps1 into the project;
     (b) no PowerShell (macOS/Linux/other) -> generate the script from **SCRIPT-SPEC.md** and self-check against its §3 list of 8 questions.
     Either way: create the timer per CRON-TEMPLATE.md (interval default 15 min, adjustable).
6. [MANDATORY] Walk FRAMEWORK.md §19.1 (new-project checklist) line by line and tick every item.
7. [MANDATORY] Run check.ps1 once after setup — output MUST be "OK" for setup to count as complete. Non-OK = not done.
```

> Treat step 6–7 as the acceptance gate. If `check.ps1` does not print OK, the project is not finished — fix and re-run.

> `poll.ps1`, `check.ps1` and `CRON-TEMPLATE.md` ship **with this package**, under `template/`. Copy them along when you duplicate the project.
> Can't run PowerShell? `SCRIPT-SPEC.md` (package root) is the contract — have your AI generate the scripts from it and verify against its 8 self-check questions.

## 13. Version

Current v1.9.7.
