# Changes 3 — Podman + forever integration + dead code removal

## Architecture summary

The system now uses three layers:

```
falconDBd        → user command, wraps podman-compose
podman-compose   → starts/stops containers (one per server), restart: always
forever          → runs inside each container, restarts node if it crashes
```

---

## Containerfile — created

**What:** Defines the Docker/Podman image for all 10 servers (one shared image,
different container per server).

**Key decisions:**
- `npm install -g forever` — installs `forever` globally so it is on `PATH`
  inside every container. This satisfies spec §5 ("kept alive using forever").
- Three separate `COPY + npm install` steps (lib, reverseProxy, dataNode) —
  preserves the professor's per-component `package.json` structure. Each
  component gets its own `node_modules/`, Node resolves upward so shared lib
  code finds its deps in `src/lib/node_modules/`.
- `ENV APP_ROOT=/app` and `ENV PATH` extension — makes `etc/bashrc` and all
  `bin/` scripts work without modification inside containers.
- `mkdir -p /app/log /app/logs /app/DBdata` — pre-creates runtime directories.
  `/app/log` is for forever's own stdout/stderr; `/app/logs` is for Winston
  log files; `/app/DBdata` is for DB key-value files.
- All control scripts made executable via `chmod +x` — Alpine images don't
  inherit execute bits from the host filesystem.

---

## docker-compose.yml — created

**What:** Defines all 10 services (rp + 9 DN containers). Adapted from the
`falconDB` reference compose file with the following changes:

### `command` — changed from `node src/.../server.js` to forever-based entrypoint

```
sh -c ". /app/etc/bashrc && forever-start.sh && exec tail -f /dev/null"
```

**Why:** `forever` daemonizes by default — it forks to background and exits the
parent process. In a container, that means PID 1 exits and the container stops
immediately. The fix: after `forever-start.sh` launches `forever` in the
background, `exec tail -f /dev/null` replaces PID 1 with a process that sleeps
forever, keeping the container alive. The Node process is kept alive by `forever`
inside the container independently of PID 1.

### `hostname` — added per service

**Why:** The DN `forever-start.sh` uses `$(hostname)` to find the right
`server.js` (e.g. `src/dataNode/dn0s1/server.js`). Without explicit hostnames,
Podman assigns random container names that wouldn't match the server IDs.

### `restart: always` — changed from `unless-stopped`

**Why:** `unless-stopped` does not restart containers that were stopped by
`podman-compose down`, but does restart on machine reboot. `always` restarts in
all crash scenarios. Either satisfies the spec; `always` is more aggressive and
leaves no ambiguity.

### `depends_on: [rp]` — on all DN services

**Why:** RP must be up before DNs start so that immediately after a DN wins the
Raft election it can call `/set_master` on the RP without connection errors.

### Volume mounts

- `./logs:/app/logs` — Winston named log files shared across all containers
  (each writes `<id>.log` and `raft-<id>.log`, no conflicts).
- `./log:/app/log` — forever's own `.out` and `.err` files per container.
- `./DBdata/<id>:/app/DBdata` — per-DN-server data directory, isolated per
  container so each server has its own independent key-value store.

---

## bin/falconDBd — rewritten

**What:** Replaced the SSH loop with `podman-compose` calls.

**Why:** The SSH model assumed real separate VMs. With Podman, the containers
ARE the hosts — SSH is redundant and would require extra SSH daemon setup inside
each container.

| Command | Old (SSH) | New (Podman) |
|---|---|---|
| `start` | SSH to each host + `forever-start.sh` | `podman-compose build` + `podman-compose up -d` |
| `stop` | SSH to each host + `forever-stop.sh` | `podman-compose down` |
| `restart` | stop + sleep + start | stop + sleep + start (unchanged logic) |
| `stat` | SSH + `forever list` | `podman ps` + `podman exec` + `forever list` |

`stat` now shows two levels: container health (via `podman ps`) AND the
`forever list` output from inside each container, giving full visibility into
both layers.

`COMPOSE_FILE` is derived from the script's own location (`dirname $0/..`)
so `falconDBd` works correctly when called from any directory.

---

## Dead code deleted

| File | Reason |
|---|---|
| `src/reverseProxy/rp.js` | Professor's skeleton — `package.json` start script now points to `server.js`; this file was never called at runtime |
| `src/reverseProxy/example.json` | Unused XML-like JSON test fixture, never required by any code |
| `src/reverseProxy/bin/basic-start.sh` | Started `node ./app.js` via nohup — both the script name and the process model are dead |
| `src/reverseProxy/bin/basic-stop.sh` | Killed by PID file written by `app.js` — same reason |
| `src/reverseProxy/bin/.start-dn.sh.swp` | Vim editor swap file, not source code |
| `src/dataNode/app.js` | Professor's Express skeleton — no start script references it anymore |
| `src/dataNode/bin/dn.js` | Professor's entry point — replaced by per-server `dn*/server.js` |
| `src/dataNode/test-luxon_sprintf.js` | Developer demo/test script, not part of the running system |
| `src/dataNode/bin/basic-start.sh` | Started `./dn.js` via nohup — both dead |
| `src/dataNode/bin/basic-stop.sh` | Killed by PID file written by `dn.js` — dead |
| `etc/ports-map.json` | Only read by `bin/dn.js` (now deleted) — orphaned |
| `etc/stat-dn.sh` | Used `jsonlint` (forbidden dep), old `dn0-s0` naming, hardcoded port 3000 — broken and unreachable |
