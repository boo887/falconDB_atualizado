# Changes made to produce the compliant serversFS project

Source: `C:\Users\maria\falconDB` (working implementation, not modified)
Target: `c:\Users\maria\Desktop\w08\serversFS` (professor's template, now populated)

---

## etc/configure.json — replaced

**What:** Replaced the professor's placeholder configure.json (old format: `dn0-s0` naming,
4 servers per DN, no ports) with the project's actual topology.

**Why:** The placeholder used a different naming convention and server count than the
rest of the code. Every server.js reads configure.json on startup — if the format
didn't match, all processes would crash immediately.

**New format:** 3 data nodes (id 0, 1, 2), each with 3 servers (`dn0s1/dn0s2/dn0s3`,
etc.), explicit hosts and ports (9001–9023), plus `reverse_proxy` and `test_client_ip`.

---

## src/lib/package.json — updated

**What:** Added `winston ^3.12.0` and `winston-daily-rotate-file ^5.0.0`.

**Why:** `logger.js` (the spec-required log wrapper module) lives in `src/lib` and
`require('winston')`. The original template lib package only had `axios` and `luxon`,
so installing lib's dependencies alone would leave winston missing. Adding it here
ensures the logger loads regardless of which component triggers the require.

---

## src/reverseProxy/package.json — updated

**What:** Added `axios ^1.15.0` and `luxon ^3.3.0`; updated `main` and `start` script
to point to `server.js`.

**Why:** `server.js` (the RP entry point) directly calls `require('axios')` for all
DN communication and `require('luxon')` for uptime tracking. In a per-component
deployment each component has its own `node_modules` — without declaring these here
they would not be found at runtime. `axios` is explicitly authorized by the spec
(§II.1.c). `luxon` is already in the professor's own template packages.

---

## src/dataNode/package.json — updated

**What:** Added `axios ^1.15.0`.

**Why:** Every DN server.js uses `require('axios')` extensively — for Raft
RequestVote/heartbeat messages, 2PC vote/abort/replicate calls, and announcing the
elected leader to the RP. Same reasoning as the RP: per-component deploys need it
declared locally.

---

## src/lib/fsdb.js — created (replaces nothing; new file in template)

**What:** Copied from falconDB. Replaced `require('md5')` with Node's built-in
`crypto.createHash('md5').update(key).digest('hex')`.

**Why:** The `md5` npm package is not present in any of the professor's template
`package.json` files. The spec §II.2.b requires md5-named files but specifies the
standard `fs` module for the FS CRUD wrapper — implying stdlib crypto, not an npm
package. `crypto` is a Node.js built-in and produces identical hex output.

---

## src/lib/shard.js — created

**What:** Copied from falconDB. Same `md5` → `crypto` fix as fsdb.js.

**Why:** `shard.js` computes which data node owns a key by hashing it. The hash
algorithm must be consistent with fsdb.js (both use md5). By switching both to
`crypto.createHash('md5')`, the hashes remain identical and no `md5` npm package
is needed.

---

## src/lib/configValidator.js — created

**What:** Copied from falconDB. Removed `require('jsonlint')` and replaced
`jsonlint.parse(raw)` with `JSON.parse(raw)`.

**Why:** `jsonlint` is not in any template package.json and has no business in
production dependencies — it is a developer linting tool. `JSON.parse` is a
JavaScript built-in that provides identical behavior for this use case: throws a
`SyntaxError` on malformed JSON, returns silently on valid JSON.

---

## src/lib/logger.js — created (no code changes)

Copied verbatim from falconDB. Creates a winston logger with custom levels
(trace/debug/info/warn/error) writing to `serversFS/logs/<filename>`.

---

## src/lib/response.js — created (no code changes)

Copied verbatim. Provides `success(data)` and `failure(code, message, errno)`
helpers that produce the normalized `{ data, error }` response format required
by spec §7.

---

## src/lib/keyUtils.js — created (no code changes)

Copied verbatim. Normalizes keys: plain strings pass through; JSON-object keys
are sorted and re-serialized so `{b,a}` and `{a,b}` hash to the same file.

---

## src/lib/netUtils.js — created (no code changes)

Copied verbatim. Provides `normalizeIP` (handles IPv6-mapped IPv4) and
`isPrivateIP` used by all route guards.

---

## src/reverseProxy/server.js — created

**What:** Copied from falconDB. Additionally replaced the two inline `md5(key)`
calls (in the CRUD response objects) with `crypto.createHash('md5')…` to be
consistent with fsdb.js and eliminate any residual dependency on the `md5` package.

**Why:** The RP server is the public entry point. It handles `/db/c`, `/db/r`,
`/db/u`, `/db/d`, `/set_master`, `/status`, `/stat`, `/admin/loglevel`, `/stop`.
It shards keys to the correct DN leader via `shard.getDN`, communicates with DNs
over HTTP using `axios`, and returns normalized responses.

---

## src/dataNode/dn{0,1,2}s{1,2,3}/server.js — 9 files created

**What:** Copied from falconDB. Each file is identical except for the `MY_ID`
constant (`dn0s1` … `dn2s3`). No path changes needed — `../../lib/*` and
`../../../etc/configure.json` resolve correctly from each subdirectory.

**Why:** The spec requires each physical server in a DN to run as an independent
process. Raft election, 2PC coordination, CRUD routing (RPt), replication, and
heartbeat are all implemented in these files. `MY_ID` is the only per-instance
variable; everything else (peers, port, DN membership) is derived from
configure.json at startup.

---

## Files kept from professor's template (not overwritten)

| File | Reason |
|---|---|
| `src/lib/utils.js` | Professor's own utility module — must be preserved as-is |
| `src/reverseProxy/rp.js` | Professor's skeleton — kept alongside our server.js |
| `src/dataNode/app.js` | Professor's Express skeleton — kept |
| `src/dataNode/bin/dn.js` | Professor's entry point skeleton — kept |
| All `bin/`, `srv/`, `etc/bashrc`, `etc/stat-dn.sh` | Infrastructure scripts — unchanged |
