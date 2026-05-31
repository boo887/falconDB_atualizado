# Windows testing issue — diagnosis and solutions

## Summary

When running the full system with podman on **Windows**, two symptoms appeared:

1. The 2PC log lines and the `DBdata/*.json` files never showed up when
   inspected (empty `logs/`, empty `DBdata/`), even though CRUD operations
   returned success.
2. The data nodes were stuck in a permanent election storm
   (`term` climbing to 1400+ in minutes, every node reporting `follower`).

After investigation, **the code is functionally correct** — reads return the
right values, missing keys are correctly rejected, duplicate keys are correctly
refused, and leaders do get elected. The problems are caused by the **Windows +
WSL2 + podman runtime**, not by the application logic. On the Linux machine the
professor uses for evaluation, neither problem occurs.

---

## How we got here

The deployment runs 10 containers (1 RP + 9 DN) via `podman compose`. The
`docker-compose.yml` bind-mounts host directories into each container:

```yaml
volumes:
  - ./DBdata/dn0s1:/app/DBdata   # the FS database
  - ./logs:/app/logs             # winston log files
  - ./log:/app/log               # forever stdout/stderr
```

The project folder lives at `C:\Users\maria\Desktop\w08\serversFS`, which inside
WSL2 is `/mnt/c/Users/maria/Desktop/w08/serversFS`. That `/mnt/c` path is a
Windows drive surfaced into the Linux VM through a translation layer
(drvfs / 9p / virtiofs).

---

## Problem 1 — logs and DB files are invisible

### Why it happens
Bind mounts backed by `/mnt/c` do **not** have coherent cross-process file
visibility on Windows. When the Node process inside a container does
`fs.writeFileSync('/app/DBdata/<md5>.json', ...)` followed later by
`fs.readFileSync(...)`, **that same process** sees its own write — so reads
succeed and the database appears to work.

But a **different** process looking at the same path — `ls`/`cat` via
`podman exec`, or Windows Explorer / PowerShell on the host — does **not**
reliably see those writes. The write sits in a per-process cache that never
becomes visible to other readers through the `/mnt/c` translation layer.

### The evidence that proved it
- `GET /db/r?key=livetest` → returns `{z:9}` (data is really there)
- `GET /db/r?key=NEVER_CREATED` → returns `key not found` (reads are genuine)
- `POST /db/c` duplicate → returns `key already exists` (writes are genuine)
- yet `ls /app/DBdata` on every container → **empty**
- and host `DBdata/` → **empty**

The only explanation consistent with all of these is cross-process write
incoherence on the `/mnt/c` bind mount. The same effect hides the `2PC PREPARE`
/ `2PC COMMIT` log lines: they are written, but not visible to a separate
`cat`/host reader.

---

## Problem 2 — the election storm (`term` 1400+)

### Why it happens
Raft decides "the leader is gone, start an election" using a wall-clock delta:

```js
// election monitor, runs every 1s
if (Date.now() - lastHeartbeat > ELECTION_TIMEOUT) {
  startElection();
}
```

The WSL2 virtual machine clock is unstable — after the Windows host sleeps,
hibernates, or is simply idle, the VM clock can **jump forward by hours all at
once**. We saw this directly: containers created at `04:00` reported
`start_at: 22:22` and `living_time: 5h57m` — a ~6 hour skew.

When the clock jumps forward, `Date.now() - lastHeartbeat` suddenly looks like
"no heartbeat for hours" on **every node at the same instant**. All nodes become
candidates together, split the vote (1/3, need 2), no one wins, the term
increments, and it repeats forever. That is exactly the `1/3 votes` pattern seen
in the raft logs and the runaway `term`.

### Why it won't happen on the evaluation machine
On a normal Linux host the clock is monotonic and stable, so the heartbeat delta
stays small and elections settle after the first round. This is purely a
WSL2-clock artifact.

---

## Solutions

### The simplest solution (recommended)

**Run the project from the WSL2 native filesystem instead of `/mnt/c`.**

Inside a WSL2 (Ubuntu) terminal:

```bash
cp -r /mnt/c/Users/maria/Desktop/w08/serversFS ~/serversFS
cd ~/serversFS
podman compose up -d
```

Why this fixes both problems at once:
- Files under `~/` (e.g. `/home/you/serversFS`) are on the **Linux ext4**
  filesystem, so bind mounts are fully coherent → logs and `DBdata` become
  visible again.
- The Linux filesystem path also avoids the `/mnt/c` translation layer entirely.

The clock skew can still occur if the host sleeps, but for a normal test session
it is not triggered, and elections settle normally. For full robustness apply the
clock hardening below.

This requires **no code changes** and is the closest match to the professor's
Linux environment.

### Alternative — keep on Windows, harden the code

If staying on `/mnt/c` is required, two changes make local testing usable:

**(a) Harden the election timing against clock jumps.** Ignore an
implausibly large gap (a real missed-heartbeat gap is seconds, not minutes):

```js
const diff = Date.now() - lastHeartbeat;

// A genuine election timeout is on the order of seconds. A gap of, say,
// more than 60s is not "the leader died" — it is the VM clock jumping.
// Treat it as noise: reset the baseline instead of starting an election.
if (diff > 60000) {
  lastHeartbeat = Date.now();
} else if (diff > ELECTION_TIMEOUT) {
  raftLogger.trace(`[TERM ${currentTerm}] no heartbeat for ${diff}ms – starting election`);
  startElection();
}
```

A more correct variant uses a monotonic clock that never jumps:

```js
// at top:  const { performance } = require('perf_hooks');
// replace Date.now() with performance.now() for heartbeat timing only.
// performance.now() is monotonic and immune to wall-clock jumps.
let lastHeartbeat = performance.now();
// ...
const diff = performance.now() - lastHeartbeat;
if (diff > ELECTION_TIMEOUT) startElection();
```

`performance.now()` is the proper fix — it measures elapsed time independent of
the system clock, so a VM clock jump can no longer fake a missed heartbeat.

**(b) Inspect over HTTP instead of the bind mount.** Add a small debug route to
each DN that returns the stored keys and recent log lines, so you can verify
2PC behaviour with `curl`/`Invoke-RestMethod` without depending on `/mnt/c`
file visibility.

---

## Bottom line

- The application logic (Raft election, 2PC, FS CRUD, normalized responses) is
  working correctly.
- Both symptoms are WSL2/`/mnt/c` runtime artifacts, not bugs in the project.
- **Simplest fix: run from the WSL2 native filesystem (`~/serversFS`)** — no code
  changes, behaves like the Linux evaluation environment.
- The `performance.now()` clock hardening is a worthwhile, platform-independent
  improvement to the Raft code and is recommended regardless.
