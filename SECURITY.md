# Security Policy

MonkMode requests root privileges on the user's Mac to modify `/etc/hosts`,
`/etc/pf.conf`, and `/Library/LaunchDaemons`. A defect in the application or
the release pipeline can therefore escalate to root code execution on user
machines. We take reports seriously.

## Supported versions

Only the latest tagged release on the `main` branch receives security fixes.
Older DMGs in the GitHub releases archive are left in place for historical
reference but should be considered end-of-life on release of their successor.

| Version | Supported |
|---------|-----------|
| Latest release on `main` | ✅ |
| Any prior release | ❌ |

## Reporting a vulnerability

**Do not open a public GitHub issue for a security report.** Instead, please
use one of the private channels below:

1. **Preferred — GitHub Security Advisories**
   Visit [Security → Advisories → Report a vulnerability](https://github.com/gilbertsahumada/monk-mode/security/advisories/new)
   on this repository. GitHub routes the report directly to the maintainers
   with no intermediate party.
2. **Email** — `gilbertsahumada@gmail.com`. Use subject line
   `[MonkMode security] <short description>`. If you want an encrypted
   channel, include your PGP key in the message and the maintainer will
   reply in kind.

Please include, if you have them:

- A short description of the issue and why it matters.
- A proof-of-concept or minimal reproduction.
- The version (git commit or release tag) you tested against.
- Your name or alias if you'd like credit in the advisory.

## Response SLA

The maintainer is a single individual. Best-effort targets:

- **Acknowledgement:** within 72 hours of report.
- **Initial assessment and severity classification:** within 7 days.
- **Fix and coordinated disclosure:** within 30 days for high severity,
  90 days for medium, no strict window for low. Public disclosure via a
  GitHub Security Advisory and release notes.

If you haven't heard back within a week, email a nudge with `[nudge]` in the
subject; the original report may have been missed.

## Safe harbor

Good-faith research is welcome. You will not be pursued for:

- Probing the application in a disposable VM or on hardware you own.
- Reverse-engineering the DMG, the enforcer binary, or the daemon plists.
- Testing against a fresh install where you are the only user.

Please refrain from:

- Running attacks against a system you do not own.
- Exfiltrating or modifying another user's data.
- Denial-of-service testing against public infrastructure (GitHub Pages,
  release assets).

## Disclosure practice

After a fix ships in a signed, notarized release we publish the advisory on
the repository's Security tab with a CVE when appropriate. Reporters are
credited unless they request otherwise.

## Logging and data

MonkMode writes three files under `/Library/Application Support/MonkMode/`:

| File | Mode | Content | Redaction |
|------|------|---------|-----------|
| `config.json` | 0644 (root-owned, world-readable) | start/end time, blocked sites | No — block list is chosen by the user |
| `ip_cache.json` | 0644 | resolved IPs per blocked domain | No — public DNS data |
| `hosts.backup` | 0600 (root-only) | snapshot of `/etc/hosts` before the block | Not accessible to other users |
| `install.log` | 0640 | timing + exit codes of the privileged install | No domain names |
| `enforcer.log` | 0644 | actions taken by the 60 s daemon | Domain-shaped tokens replaced with `<domain>`; rotates at 1 MB |

The enforcer never sends anything off the machine. No telemetry, no
crash reporting, no remote update beacon. If a future release needs any
network activity beyond the one-time DoH-blocklist refresh (#26), it
will be documented here and gated behind an opt-in.

Run the enforcer with `MONKMODE_LOG_VERBOSE=1` in its environment to
disable redaction when debugging.

## Out of scope

The following are documented trade-offs, not vulnerabilities:

- The user can physically remove the Mac's hard drive and edit `/etc/hosts`
  from another boot. MonkMode does not claim to survive physical access.
- Users with existing root access can of course defeat the block. The
  threat model is a user committing to a block while retaining normal
  account-level privileges.
- An attacker who already has root on the target Mac can tamper with
  any file MonkMode writes. We are not a defense against pre-existing
  root compromise.

## Living documents

This policy lives in the repository alongside [`docs/THREAT_MODEL.md`](docs/THREAT_MODEL.md)
and the security tracker in [issue #14](https://github.com/gilbertsahumada/monk-mode/issues/14).
Both are updated as the project evolves; pull requests that materially
change security posture must update them.
