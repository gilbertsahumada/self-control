# DoH Blocklist Update Design

Status: draft. Implementation tracked in [#26](https://github.com/gilbertsahumada/monk-mode/issues/26).
Depends on the signing infrastructure tracked in Phase 3 (#19).

## Problem

`DomainExpander.dohDomains` and `DomainExpander.dohIPs` are compiled
into the enforcer binary. Every time a new DNS-over-HTTPS provider
becomes popular, or an existing one rotates to a new IP range, users
running an older release silently lose a piece of the block. Without
a remote-update path we must ship a new DMG for every change.

## Goals

1. New DoH providers can be added without a user-facing release.
2. An unauthenticated attacker cannot push a malicious list — the
   update mechanism must not become a privilege-escalation channel.
3. The enforcer falls back to the last-known-good list on any kind of
   fetch failure (network down, signature invalid, TLS error).
4. Users can opt out entirely and stay on the baked-in list.

## Non-goals

- Realtime updates. A daily refresh is sufficient.
- Fine-grained per-user targeting. The list is the same for everyone.
- Self-serve list management by users. Only maintainers publish.

## Data format

```
MONKMODE DoH BLOCKLIST v1
generated-at: 2026-05-12T00:00:00Z
valid-until:  2026-06-11T00:00:00Z

# Provider domains to force through system DNS.
[domains]
dns.google
cloudflare-dns.com
...

# IPs (IPv4 and IPv6) to drop via pf on port 443.
[ips]
8.8.8.8
2001:4860:4860::8888
...
```

Parsed into the existing `IPCache` and `dohDomains` structures before
the enforcer's next write of `/etc/hosts` + pf rules.

## Trust

- Published as `blocklist.txt` on a static origin controlled by the
  maintainer (GitHub Pages or an R2 bucket). HTTPS only.
- Signed with [minisign](https://jedisct1.github.io/minisign/) to a
  detached `blocklist.txt.minisig`. Two pinned public keys are baked
  into the enforcer: a primary signing key and a rotation key. Either
  can sign; compromise of one lets the other rotate.
- The enforcer refuses any list whose signature fails, whose
  `valid-until` is in the past, or whose format version is unknown.
- On any failure it keeps using the cached last-known-good list (or
  the baked-in defaults if no cache exists yet).

## Update flow

1. Enforcer ticks (every 60 s). On startup and then once per 24 h it
   fetches `blocklist.txt` + `blocklist.txt.minisig` via
   `URLSession` (no auth).
2. Verifies the signature with `swift-minisign` against one of the
   pinned keys.
3. Verifies `valid-until` is in the future and the format version
   matches what the current enforcer understands.
4. Writes the list to
   `/Library/Application Support/MonkMode/doh_blocklist.json`
   (mode 0644, root-owned) and rebuilds pf rules on the next tick.
5. On any failure, logs a single redacted line and keeps the cached
   list. After 14 days of consecutive failures, surfaces a warning
   via the app UI.

## Key rotation

1. Generate new key pair.
2. Ship a new enforcer release pinning BOTH old and new public keys.
3. Wait two release cycles (~60 days) so users are rolled forward.
4. Sign subsequent blocklists with the new key only.
5. Next release after that drops the old key.

## Opt out

A `MONKMODE_DOH_BLOCKLIST_OFFLINE=1` env var on the enforcer plist
disables the fetch. Useful for:

- users who prefer never to make any outbound call from the daemon
- CI test runs
- air-gapped evaluation

## Open questions

- Do we need to expose the fetch in the app UI so users can see the
  "last successful update" timestamp? Leaning yes.
- Should the cache live in the enforcer's support dir or somewhere
  root-only? Currently planned for 0644 so the app can surface the
  timestamp without re-reading the raw list.
- Signature rotation ceremony — do we need a third "emergency revoke"
  key? Probably not for v1.

## Implementation blockers

- Needs a hosting target with a stable URL. GitHub Pages works but
  not ideal for a security-critical path; a dedicated custom domain
  is preferred and tied to Phase 3 release infrastructure.
- Needs the signing-key ceremony which is simpler to run once a
  Developer ID signing identity already exists (#19).
