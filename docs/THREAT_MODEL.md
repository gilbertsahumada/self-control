# MonkMode Threat Model

Last reviewed: 2026-04-23. Maintainer: @gilbertsahumada.

This document describes the assets MonkMode protects, the adversaries it
considers, the trust boundaries in its architecture, and the mitigations
currently in place. It is a living document: any pull request that changes
privileges, file layout, the privileged-script pipeline, or the release
process must update the relevant section.

## 1. Assets

| Asset | What it is | Why it matters |
|-------|------------|----------------|
| Root shell on the user's Mac | The LaunchDaemon runs as root; any RCE through the app becomes a root RCE | Loss = full control of the machine |
| Integrity of `/etc/hosts` and `/etc/pf.conf` | Files written during a block | Corruption breaks normal network access for the user |
| The user's commitment | The "you can't abort the block" promise is the product | If the block is bypassable without effort, the product has no value |
| User trust in the DMG | Open-source binary distributed via GitHub releases | If a tampered DMG ever ships, every downstream user is at risk |
| Maintainer credentials | GitHub account, signing certificate, PGP key | Compromise allows shipping a backdoor at scale |

## 2. Adversaries

| Adversary | Capability | Worst-case outcome |
|-----------|------------|--------------------|
| **A1: The user themselves at a moment of weakness** | Runs the app, types into the UI, has their own account credentials | Would like to bypass the timer; app must resist casual tampering |
| **A2: A second unprivileged user on the same Mac** | Has their own home directory, cannot sudo | Read user's block list, force cleanup, corrupt daemon state |
| **A3: Network MITM on DMG download** | Can intercept TLS-terminated traffic (compromised CA, ISP injection) | Ship a tampered DMG that runs as root once the user opens it |
| **A4: Compromised maintainer account or signing cert** | Pushes code to `main`, signs releases | Distribute a backdoored release to every user |
| **A5: Compromised upstream dependency** | npm package, Google Fonts CDN, Xcode/Swift toolchain | Inject payload into the landing page or, worst, into the app build |
| **A6: Hostile app input** | User pastes a crafted domain string | Attempt shell / sed / AppleScript injection through `BlockViewModel` into the root-run script |

Out of scope:

- Physical access to the Mac (the user can boot into recovery and edit files
  directly — MonkMode does not claim to survive offline tampering).
- Pre-existing root compromise on the target Mac (we cannot protect files we
  write if the attacker already has the capability to modify them).

## 3. Trust boundaries

```
┌──────────────────────────────────────────────────────────────┐
│ User-space (unprivileged)                                    │
│  - SwiftUI app (MonkMode.app)                                │
│  - BlockViewModel: builds privileged scripts (#15 invariant) │
│  - PrivilegedExecutor: passes scripts to NSAppleScript (#16) │
├─────────────── NSAppleScript administrator privileges ───────┤
│ Root execution context                                       │
│  - bash -c <generated script>                                │
│  - writes /etc/hosts, /etc/pf.conf, /etc/pf.anchors          │
│  - writes /Library/Application Support/MonkMode (mode 0600)  │
│  - writes /Library/LaunchDaemons/com.monkmode.*.plist        │
│  - installs /usr/local/bin/monkmode-enforcer                 │
├─────────────── LaunchDaemon runtime ─────────────────────────┤
│ Root, detached, runs every 60s + one-shot at endTime         │
│  - MonkModeEnforcer re-applies or tears down the block       │
└──────────────────────────────────────────────────────────────┘
```

Every crossing is enforced by an explicit mechanism:

- **User-space → root (NSAppleScript):** the AppleScript password dialog.
  MonkMode never stores the password.
- **Generated script → root bash:** every value interpolated into the
  script must pass through `ShellQuote` (see #15 invariant below).
- **LaunchDaemon → root bash:** plist `ProgramArguments` points at a single
  binary we own at `/usr/local/bin/monkmode-enforcer`.

### The #15 invariant

> No value interpolated into the privileged bash script may contain an
> unescaped shell, sed, or AppleScript metacharacter. All such values MUST
> be routed through `ShellQuote.posixSingleQuote`, `ShellQuote.sedBRE`, or
> `ShellQuote.appleScriptLiteral`. A violation is treated as a CVE.

Enforced by code review plus the `AdversarialInputTests` corpus. New
mitigations land as new corpus entries.

## 4. Mitigations in place

### Against A1 (user in a moment of weakness)

- No "cancel block" control in the UI.
- Enforcer daemon runs every 60s and re-writes `/etc/hosts` / `pf` from the
  persisted config, reverting any manual edits.
- A secondary LaunchDaemon fires at the exact `endTime` as a redundancy
  against primary enforcer failure.

**Known gap:** the user can edit `/etc/hosts` as root between enforcer
ticks. We do not attempt to be tamper-proof against the user's own root.

### Against A2 (another unprivileged user on the same Mac)

- `/Library/Application Support/MonkMode/` config files are created with
  mode `0600` and owned by root (see #24 for the permissions audit task).
- The privileged script validates inputs (#17 `DomainValidator`) before
  writing them, so one user cannot craft input that leaks via the log.

**Known gap:** an audit of every file we create for mode and ownership is
tracked in #24 and will be verified by the smoke test.

### Against A3 (MITM on DMG download)

- GitHub serves the DMG over HTTPS with certificate pinning on the
  browser side.
- We are moving from ad-hoc signing to Developer ID signing + Apple
  notarization (tracked in #19). Once notarized, macOS Gatekeeper will
  refuse to run a tampered DMG without requiring `xattr -cr`.
- SHA256 checksums published alongside each release (tracked in #20).

**Known gap:** today the install docs tell users to run `xattr -cr`
which disables Gatekeeper. Until #19 ships, a compromised download
still executes. This is the #1 priority after Phase 1.

### Against A4 (compromised maintainer)

- Branch protection on `main` requires a reviewed pull request plus
  passing status checks, disallows force-push, and requires signed
  commits (see #21).
- `CODEOWNERS` requires an owner approval for PRs that touch the
  privileged script generator, the enforcer, or release workflows.
- Releases are moving to a reproducible CI-only workflow triggered by
  a signed tag; the certificate lives in GitHub secrets, not on any
  maintainer laptop (#23).
- Two-factor authentication with a hardware key is mandatory on the
  maintainer's GitHub account.

**Known gap:** GitHub Secrets are fetched by any workflow the maintainer
authorizes — a malicious workflow on a feature branch could read them
if branch protection is ever weakened. Review requirements on
`.github/workflows/` close this gap.

### Against A5 (compromised upstream dependency)

- Swift targets depend on `Foundation`, `SwiftUI`, `AppKit`, and
  `XCTest` only. No third-party Swift packages.
- Web targets have a small React + Vite footprint; `yarn audit --level high`
  gates CI (#27).
- JetBrains Mono currently loads from Google Fonts CDN; self-hosted
  copy tracked in #28 for fewer third-party fetches at runtime.
- Renovate / Dependabot bumps dependencies weekly with a security label.

### Against A6 (hostile app input)

- `DomainValidator` rejects control characters, non-ASCII, IP-like
  strings, structural violations, URLs, paths, and shell metacharacters.
- `ShellQuote` rejects any control character in any value before quoting.
- `AdversarialInputTests` enforces this on every build with a corpus of
  40+ attack strings.

## 5. Residual risk

Risks we accept today because mitigation cost is not yet justified or is
deferred to a later phase:

1. **Ad-hoc code signing until #19 closes.** A tampered DMG runs if the
   user follows the documented `xattr -cr` step. Priority P1.
2. **No signed DoH blocklist updates (#26).** A DoH provider added after
   the last release is not blocked. Low exploit value (only helps the
   user bypass themselves); not a privilege-escalation risk.
3. **Fonts via Google Fonts CDN (#28).** Leaks visitor IP per page load.
   Landing page only, no data or privilege.
4. **Enforcer log is not redacted by default (#25).** Domain names the
   user chose to block are written to `/Library/Application Support/
   MonkMode/enforcer.log`. Not world-readable once #24 closes.

## 6. Change control

This document must be updated before merging any PR that:

- Adds or removes a trust boundary.
- Changes the set of files written by the privileged script.
- Changes the enforcer's execution schedule or privileges.
- Modifies the release pipeline, signing keys, or branch protection.
- Introduces a new third-party dependency.

Reviewers should treat an out-of-date threat model as a blocking comment.
