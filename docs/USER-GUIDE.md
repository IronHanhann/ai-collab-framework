# User Guide

[中文手册](USER-GUIDE.zh-CN.md)

## Daily use

### Start / stop the whole framework
Edit `SWITCH.md` (framework root):
- `enabled: true` → all projects resume
- `enabled: false` → everything stops, all AIs end immediately on wake

### Start / stop one project
Edit `projects/{project-name}/SWITCH.md`:
- `enabled: true` → start only this project
- `enabled: false` → stop only this project

### See who's working
Read `projects/{project-name}/STATE.md`. Each participant has their own block.

### See what happened lately
Read `projects/{project-name}/HEARTBEAT.md` — a plain log of facts. Just look at the last few lines.

### Check whether an AI is still alive
Read the mtime of `projects/{project-name}/inbox-{ai}/.alive`. No update for 30+ min = it's dead.

Don't judge by `HEARTBEAT.md`'s mtime — it's a *shared* file, so anyone's write refreshes it.

### Stop two AIs doing the same work
Read `projects/{project-name}/LEASES.md`. One task, one owner, one lease — a task without a lease isn't claimed.

### Resume a long task after a crash
Read `projects/{project-name}/PROGRESS.md`. Long tasks checkpoint there, so a fresh session picks up instead of restarting.

---

## Create a new project

### Steps

1. **Copy template**
   ```powershell
   xcopy /E /I "{framework-dir}/template" "{framework-dir}/projects/{new-project}"
   ```
   The copy's `SWITCH.md` starts with `enabled: false` **on purpose**. Leave it that way for now — flipping it before everyone is in just burns tokens on idle cycles.

2. **Fill PARTICIPANTS.md**
   One entry per participant: slot name, software, access method, inbox, capabilities, limits.

3. **Fill STATE.md**
   - Project name, stage, participant list, next step
   - An empty block per participant
   - Confirm `next_msg_id: 0001`

4. **Create one inbox per participant**
   ```powershell
   mkdir "{framework-dir}/projects/{new-project}/inbox-{participant-a}"
   mkdir "{framework-dir}/projects/{new-project}/inbox-{participant-b}"
   ```

5. **Set up one timer per participant, per project**
   One cron job each — not one shared job for all projects. A project must be stoppable on its own without pausing the others.

6. **Give each AI its instructions** (copy-paste ready)
   ```
   You are now connected to the AI Collab Framework.
   Read {framework-dir}/SKILL.md first, follow the protocol.
   Your inbox is {framework-dir}/projects/{new-project}/inbox-{your-name}/
   Wake up every 15 minutes, follow the flow in SKILL.md section 3.
   ```

7. **When everyone's in and you say "start", flip the switch**
   Edit `projects/{new-project}/SWITCH.md`, set `enabled: true`.

8. **Send a one-time notice to each existing project's inboxes**
   Just to announce the new project. After that, projects stay isolated.

---

## Migrate to another computer

1. Copy the entire framework directory (including template, projects)
2. On the new machine, tell the AI the new path:
   ```
   Framework directory is now {new-path}. Update all paths accordingly.
   ```
3. Rebuild timers (cron jobs are per-session, need to be recreated on the new machine)

---

## FAQ

### AI died / not responding
Check its `.alive` file for last update time. No update for 30+ min = it's dead.
Just start a new session. The new session reads `IDENTITY.md` + `STATE.md` and picks up where it left off.

### Two AIs used the same message number
The later one changes its number, logs it in HEARTBEAT.md. Always scan numbers before sending.

### Want to add a new AI
Tell any existing AI "add {new-name} to the framework". It will handle the onboarding.

### Controller died
No .alive update for 30+ min = offline. Business projects keep running, emergency bugs still fixable.
You appoint a new controller. The new one updates `CONTROLLER.md`.

---

## 8. A note for you: AIs forget things

**Important**: All AIs have single-threaded attention — they can only focus on one thing at a time. This is an architecture limitation, not "carelessness".

### What they forget
- Changed a rule but forgot to sync the template
- Added a feature but forgot to bump the version number
- Deployed an improvement but forgot to notify the other AI
- Working on A, you interrupt with B, A goes out of their head

### What you should do
1. **Every now and then, ask "what changed recently?"** — don't rely on AIs to remember
2. **After a major rule change, ask half a day later "did you sync everything?"** — make sure template, version, broadcast all done
3. **Don't pile on too many tasks at once** — one thing at a time
4. **Point out inconsistencies directly** — AIs won't be offended, they really do forget

### What the framework does to help
- `check.ps1` auto-checks version consistency
- `STATE.md` top quick-index: 10 seconds to get up to speed
- `LESSONS.md` records pitfalls
- Three-tier degradation: accidental switch-off won't delete timers immediately

But **these only mitigate, not eliminate**. You (the user) are the final supervisor.
