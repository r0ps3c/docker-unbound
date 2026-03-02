# Project Specification: docker-unbound

## Overview
Lightweight Docker image for [Unbound](https://nlnetlabs.nl/projects/unbound/) DNS resolver built on Alpine Linux, with automated CI/CD, dependency management, and comprehensive testing.

## Docker Image

### Build
- Base: `alpine:3.23` (pinned for Renovate tracking; digest-pinned by Renovate after first run)
- Packages: `unbound=1.24.2-r0` (version-pinned for Renovate tracking), `bind-tools` (APK cache cleared after install)
- Directories: `/var/run/unbound` created; `/etc/unbound` and `/var/run/unbound` owned by `unbound:unbound`
- Target image size: < 50 MB

### Runtime
- User: `unbound` (non-root)
- Ports: `53/tcp`, `53/udp`
- Entrypoint: `/usr/sbin/unbound -d`
- Health check: `nslookup -type=NS . 127.0.0.1`, interval 30s, timeout 3s, start period 5s, retries 3
- Default config: localhost-only listening and access control; mount custom config at `/etc/unbound/unbound.conf` for container networking

## Testing

Three POSIX sh test suites share a common library (`tests/lib/common.sh`). Test config at `tests/configs/unbound-test.conf` enables network-wide access for runtime tests.

### Structure Tests (`tests/structure.sh`) — 14 tests
Static image inspection (container runs with overridden entrypoint):
- Ports 53/tcp and 53/udp exposed in image metadata
- Binaries exist and executable: `/usr/sbin/unbound`, `/usr/sbin/unbound-checkconf`, `/usr/sbin/unbound-control`
- Packages installed: `unbound`, `libevent`, `dnssec-root`
- Config directory `/etc/unbound` exists; DNSSEC root key present (warn-only if missing)
- APK cache empty; no temp files in `/tmp`
- Image size < 50 MB; base image is Alpine Linux
- Unbound version extractable and valid semver

### Standalone Tests (`tests/standalone.sh`) — 12 tests
Single-container runtime with test config, port-mapped `53→15353/udp`:
- Container stability; Unbound process running with `-d` flag
- Port 53 listening on UDP and TCP
- Startup confirmed in logs; no fatal errors in logs
- Config validates via `unbound-checkconf`
- DNS resolves internally (localhost) and from host on port 15353
- `unbound-control` available; container still running after all tests

### Integration Tests (`tests/integration.sh`) — 14 tests
Two-container setup on a dedicated Docker network: Unbound container (alias `unbound`) + Alpine client with `bind-tools`:
- Container stability; client reaches Unbound over network
- A record (`google.com`), alternative domain, AAAA (warn), MX (warn)
- Load test: 10 queries, ≥ 8 succeed
- Caching: second query time ≤ first query time
- TCP DNS queries; simultaneous queries (warn)
- Multiple TLDs: ≥ 3 of 4 (`google.com`, `github.io`, `wikipedia.org`, `example.net`)
- No fatal errors in logs; container still running after load

### Makefile Targets
| Target | Description |
|---|---|
| `build` | Build image as `unbound-network:main` (with `--pull`) |
| `test-structure` | Run structure tests |
| `test-standalone` | Run standalone tests |
| `test-integration` | Run integration tests |
| `test-all` | Run all three suites |
| `clean-test` | Remove all `unbound-test-*` containers, volumes, and networks |
| `version` / `show-version` | Extract Unbound version from built image |

Version extraction: `apk info unbound 2>/dev/null | grep "^unbound-" | head -1 | cut -d- -f2 | cut -dr -f1`

## Dependency Management (Renovate)

`renovate.json` configuration:
- Extends `config:recommended`; dependency dashboard disabled; timezone UTC
- Global minimum release age: 2 days; PR labels: `dependencies`; concurrent PR limit: 5; hourly limit: 2
- Vulnerability alerts enabled

| Dependency | Manager/Datasource | Minor/Patch/Digest | Major |
|---|---|---|---|
| Alpine base image | docker | Auto-merge (squash, 2-day wait, tests required, digest-pinned) | Manual review; reviewer: `r0ps3c` |
| GitHub Actions | github-actions | Auto-merge (squash, 2-day wait, pin digests) | Manual review |
| Unbound APK | regex / repology (`alpine_{{major}}_{{minor}}/unbound`) | Auto-merge (squash, 2-day wait) | Manual review; reviewer: `r0ps3c` |

Custom regex manager tracks Unbound version in `Dockerfile` via a multiline pattern that captures the Alpine version from the `FROM` line and the unbound version from the `apk add` line. The `lookupNameTemplate` is constructed dynamically (`alpine_{{alpineMajor}}_{{alpineMinor}}/unbound`), so it stays in sync with the pinned Alpine version automatically when Renovate bumps it. The regex captures only the upstream version (e.g. `1.24.2`), excluding the Alpine revision suffix (`-r0`), so repology version comparisons work correctly.

## CI/CD

### Workflows
- `build-and-tag.yml` — Build, scan, test, and publish
- `check-major-version-bump.yml` — Stable promotion automation

Renovate runs via the [Renovate GitHub App](https://github.com/apps/renovate) (no workflow required).

### Build Triggers
Push or PR to `main`/`stable`; manual dispatch.

### Pipeline Steps
1. Build image (`docker build --pull`)
2. Trivy security scan (CRITICAL/HIGH/MEDIUM; fails build on fixable CRITICAL/HIGH; uploads SARIF to GitHub Security tab)
3. Run all three test suites
4. Extract Unbound version from built image
5. Apply tags and push to `ghcr.io`

## Branch Strategy and Tagging

### Main Branch Tags
| Tag | Condition |
|---|---|
| `main`, `latest` | Always |
| `<major>.<minor>.<patch>` | Always (immutable) |
| `<major>` | Always |
| `stable` | Only if major version matches current stable |

### Stable Branch Tags
| Tag | Condition |
|---|---|
| `stable` | Always |

### Stable Promotion
After a successful main build, `check-major-version-bump.yml` opens a PR if the Unbound major version on main differs from stable (or stable branch doesn't exist):
- PR: `main` → `stable`, branch `update-stable-v<major>`
- Labels: `stable-promotion`, `major-version-bump`
- Requires manual review and approval

## Permissions

| Workflow | Required Permissions |
|---|---|
| Build | `contents:read`, `packages:write`, `security-events:write` |
| Promotion check | `contents:write`, `pull-requests:write` |
| Renovate | `contents:write`, `pull-requests:write`, `issues:write` |

## Repository Setup

1. GitHub Actions: read/write permissions + allow creating PRs
2. `stable` branch protection: require 1 PR review; require status checks to pass
3. Install [Renovate GitHub App](https://github.com/apps/renovate); merge onboarding PR
4. Enable "Allow auto-merge" on the repository for Renovate auto-merge to function
