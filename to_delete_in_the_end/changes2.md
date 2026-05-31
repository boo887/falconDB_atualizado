# Changes 2 — falconDBd, forever wiring, naming fixes

## bin/falconDBd — created

**What:** New bash script that orchestrates the entire distributed system.
Supports `start`, `stop`, `restart`, `stat`.

**Why:** The spec §3 explicitly requires a `falconDBd` command to manage the DB.
Without it the project has no way to start or stop the system as a whole.

**How it works:**
- `start` — SSHes to all 9 DN hosts in parallel (background `&`), waits for them
  to be up, then starts the RP. DNs go first so Raft elections can run and
  leaders can announce themselves to the RP as it comes up.
- `stop` — RP first (no new requests accepted), then all DNs in parallel.
- `restart` — calls stop, waits 2 seconds, calls start.
- `stat` — SSHes to every host and runs `forever list`.

Each host is reached via SSH and told to run its own `forever-start.sh` /
`forever-stop.sh`, which are already on the `PATH` via `etc/bashrc`.

---

## etc/bashrc — updated (3 changes)

### Change 1: `servers_n=4` → `servers_n=3`

**Why:** The project has 3 servers per data node (s1, s2, s3), not 4.
The old value was left over from the professor's placeholder template.
`servers_n` is used in usage messages and bounds checks.

### Change 2: `def_host` function rewritten

**Why:** The old function converted inputs to `dn0-s0` style (hyphenated,
0-indexed). The project uses `dn0s1` style (no hyphen, 1-indexed) to match
`configure.json`, hostnames, and server IDs throughout the codebase.

New behaviour: `0-1` or `01` → `dn0s1`; `2-3` or `23` → `dn2s3`.
Range validation updated to `[1-3]` for server index (was `[0-3]`).

### Change 3: shell aliases updated

**Why:** The old aliases included `00`, `03`, `10`, `13`, `20`, `23`, `30`–`33`
which referred to server index 0 and DN 3 — neither of which exist in this project.
Keeping them would produce confusing errors when used.

Removed: `00 03 10 13 20 23 30 31 32 33`
Kept: `01 02 03 11 12 13 21 22 23` (DN 0–2, server 1–3)

---

## src/reverseProxy/bin/forever-start.sh — updated

**What:** Changed `base=rp.js` → `base=server.js`

**Why:** The RP entry point is `server.js` (our implementation). The professor's
skeleton `rp.js` is kept as reference but is not the running server. `forever`
identifies processes by the script filename, so this must match exactly.

---

## src/reverseProxy/bin/forever-stop.sh — updated

**What:** Changed `base=rp.js` → `base=server.js`

**Why:** Same reason — `forever stop` matches by script name. If the name
differs from what was used to start, `forever stop` silently does nothing.

---

## src/dataNode/bin/forever-start.sh — rewritten

**What:** Replaced the hardcoded `base=dn.js` approach with a hostname-derived
path: `$APP_ROOT/src/dataNode/$(hostname)/server.js`.

**Why:** The old script started `bin/dn.js` (the professor's generic entry point).
Our project has per-server files at `src/dataNode/dn0s1/server.js`, etc.
Since each physical server has a hostname matching its server ID (e.g. `dn0s1`),
using `$(hostname)` automatically selects the correct `server.js` to start.

---

## src/dataNode/bin/forever-stop.sh — rewritten

**What:** Same hostname-derived path as `forever-start.sh`.

**Why:** `forever stop` must be given the exact same script path used at start
time. Using `$(hostname)` ensures the right instance is stopped.

---

## src/lib/fsdb.js — DBdata auto-create guard added

**What:** Added `fs.mkdirSync(DBPATH, { recursive: true })` after `DBPATH` is
defined, guarded by `!fs.existsSync(DBPATH)`.

**Why:** On a fresh deployment the `DBdata/` directory does not exist. The first
`create` call would throw a `ENOENT` error because `fs.writeFileSync` cannot
write into a non-existent directory. `logger.js` already does the same thing for
`logs/`. Making `fsdb.js` consistent with that pattern ensures the system works
on first boot without any manual setup step.
